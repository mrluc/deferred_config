defmodule DeferredConfig do  
  @moduledoc """
  Seamlessly add runtime config to your library, with the
  "system tuples" or the `{m,f,a}` patterns.

  # Seamlessly?

  In your application startup, add the following line:

      defmodule Mine.Application do
        def start(_type, _args) do
          :mine |> DeferredConfig.populate_system_tuples
          ...
        end
      end

  Where `:mine` is the name of your OTP app.
  
  Now you and users of your app or lib can configure
  as follows, and it'll work -- regardless of if they're
  running it from iex, or a release with env vars set:
  
      config :mine, 
      
        # string from env var, or `nil` if missing.
        port1: {:system, "PORT"},

        # string from env var |> integer; `nil` if missing.
        port2: {:system, "PORT", {String, :to_integer}},
        
        # string from env var, or "4000" as default.
        port3: {:system, "PORT", "4000"},
        
        # converts env var to integer, or 4000 as default.
        port4: {:system, "PORT", 4000, {String, :to_integer}}
  
  **Accessing config does not change.**
  
  Since you can use arbitrary transformation functions,
  you can do advanced transformations if you need to:

      # lib/mine/ip.ex
      defmodule Mine.Ip do
        @doc ":inet_res uses `{0,0,0,0}` for ipv4 addrs"
        def str2ip(str) do
          case :inet_parse:address(str) do
            {:ok, ip = {_, _, _, _}} -> ip
            {:error, _}              -> nil
          end
        end
      end

      # config.exs 
      config :my_app,
        port: {:system, "MY_IP", {127,0,0,1}, {Mine.Ip, :str2ip}

  Note that this only applies to **one OTP app's config.**
  We can't (and shouldn't try to) monkey-patch every app's 
  config; they all start up at different times.
  
  If you have another use case that this doesn't cover, 
  please file an issue or reach out to github.com/mrluc

  See `README.md` for explanation of rationale. 
  **TL;DR:** `REPLACE_OS_VARS` is string-only and release-only,
  and `{:system, ...}` support among libraries is spotty
  and easy to get wrong in ways that bite your users
  come release time. This library tries to make it easier
  to do the right thing. Other libraries add special
  config files and/or special config accessors, which
  is more complex than necessary.
  """
  require Logger
  
  
  @doc """
  Support the "system tuples" pattern of config for `app`.
  Best run during `Application.start/2`.

  Populates tuples like `{:system, "VAR" ...}` in app
  config by calling `System.get_env("VAR")`, with optional
  defaults and additional processing supported. See
  `Peerage.DeferredConfig.get_system_tuple/1` for
  details.
  """
  def populate_system_tuples(app) do
    e = app |> Application.get_all_env
    walk_cfg(app, e, &recognize_system_tuple/1, &get_system_tuple/1)
    walk_cfg(app, e, &recognize_mfa_tuple/1, &transform_mfa_tuple/1)
  end

  @doc """
  Support the "module, function, arguments" pattern of runtime config
  for `app`. Populates tuples like `{:apply, {mod, fun, args}}`,
  by calling `apply(m,f,a)` in app config.
  """
  def populate_apply_tuples(app) do
    
  end

  @doc """
  Recognize mfa tuple of form `{:apply, {File, :read!, ["name"]}}`.
  """
  def recognize_mfa_tuple({:apply, {m,f,a}}), do: true
  def recognize_mfa_tuple(_),                 do: false
  @doc "Apply module, function, arguments tuple."
  def transform_mfa_tuple({:apply, {m,f,a}}), do: apply(m,f,a)
  
  @doc """
  Recognizer for system tuples of forms:
  - `{:system, "VAR"}`
  - `{:system, "VAR", default_value}`
  - `{:system, "VAR", {String, :to_integer}}`
  - `{:system, "VAR", default_value, {String, :to_integer}}`
  """
  def recognize_system_tuple({:system, ""<>_k}),           do: true
  def recognize_system_tuple({:system, ""<>_k, _default}), do: true
  def recognize_system_tuple({:system, ""<>_k, _d, _mf}),  do: true
  def recognize_system_tuple(_),                               do: false

  @doc """
  Transform recognized system tuples, getting from env and
  optionally converting it or returning default.
  """
  def get_system_tuple({:system, k}), do: System.get_env(k)
  def get_system_tuple({:system, k, {m, f}}) do
    apply m, f, [ System.get_env(k) ]
  end
  def get_system_tuple({:system, k, d}), do: System.get_env(k) || d
  def get_system_tuple({:system, k, d, {m, f}}) do
    (val = System.get_env k) && apply(m, f, [val]) || d
  end
  def get_system_tuple(t), do: throw "Could not fetch: #{inspect t}"

  
  # toplevel. really, these are the app keys; everything underneath
  #  is nested, so only these need to be SET; underneath, it just needs
  #  to be TRANSFORMED
  def walk_cfg(app, config, recognize, transform)
  def walk_cfg(_, [], _, _), do: :ok
  def walk_cfg(app, [{k, v} | ls], recognize, transform) do
    v = v |> ReplacingWalk.walk(recognize, transform)
    app |> Application.put_env(k, v)
    app |> walk_cfg(ls, recognize, transform)
  end
    
end

