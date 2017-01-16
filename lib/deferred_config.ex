defmodule DeferredConfig do  
  @moduledoc """
  Seamlessly add runtime config to your library, with the
  "system tuples" or the `{m,f,a}` patterns.

  # Seamlessly?

  In your application startup, add the following line:

      defmodule Mine.Application do
        def start(_type, _args) do
          DeferredConfig.populate(:mine)  # <-- this one
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

  See `README.md` for explanation of rationale. 
  **TL;DR:** `REPLACE_OS_VARS` is string-only and release-only,
  and `{:system, ...}` support among libraries is spotty
  and easy to get wrong in ways that bite your users
  come release time. This library tries to make it easier
  to do the right thing with 1 LOC. Other libraries add special
  config files and/or special config accessors, which
  is more complex than necessary.
  """
  require Logger
  import ReplacingWalk, only: [walk: 3]
  
  @default_rts [
    {&DeferredConfig.recognize_system_tuple/1,
     &DeferredConfig.get_system_tuple/1},
    {&DeferredConfig.recognize_mfa_tuple/1,
     &DeferredConfig.transform_mfa_tuple/1}
  ]
  
  @doc """
  Populate deferred values in an app's config.
  Best run during `Application.start/2`.

  **By default** attempts to populate the common 
  `{:system, "VAR"}` tuple form for getting values from
  `System.get_env/1`, and the more
  general `{:apply, {Mod, fun, [args]}}` form as well.

  System tuples support optional
  defaults and conversion functions, see
  `Peerage.DeferredConfig.get_system_tuple/1`.

  Can be extended by passing in a different 
  enumerable of `{&recognizer/1, &transformer/1}` 
  functions.
  """
  def populate(app, transforms \\ @default_rts) do
    :ok = app
    |> Application.get_all_env
    |> transform_cfg(transforms)
    |> apply_transformed_cfg!(app)
  end

  @doc """
  Given a config kvlist, and an enumerable of 
  `{&recognize/1, &transform/1}` functions,
  returns a kvlist with the values transformed
  via replacing walk.
  """
  def transform_cfg(cfg, rts \\ @default_rts) when is_list(rts) do
    Enum.map(cfg, fn {k,v} ->
      {k, apply_rts(v, rts)}
    end)
  end

  @doc "`Application.put_env/3` for config kvlist"
  def apply_transformed_cfg!(kvlist, app) do
    kvlist
    |> Enum.each(fn {k,v} ->
      Application.put_env(app, k, v)
    end)
  end

  @doc """
  Default recognize/transform pairs used in
  populating deferred config. Currently
  r/t pairs for :system tuples and :apply mfa tuples.
  """
  def default_transforms(), do: @default_rts

  # apply sequence of replacing walks to a value
  defp apply_rts(val, []), do: val
  defp apply_rts(val, rts) when is_list(rts) do
    Enum.reduce(rts, val, fn {r, t}, acc_v ->
      walk(acc_v, r, t)
    end)
  end

  @doc """
  Recognize mfa tuple, like `{:apply, {File, :read!, ["name"]}}`.
  Returns `true` on recognition, `false` otherwise.
  """
  def recognize_mfa_tuple({:apply, {m,f,a}})
  when is_atom(m) and is_atom(f) and is_list(a),
    do: true
  def recognize_mfa_tuple({:apply, t}) do
    Logger.error "badcfg - :apply needs {:m, :f, lst}. "<>
      "given: #{ inspect t }"
    false
  end
  def recognize_mfa_tuple(_), do: false
  
  @doc "Return evaluated `{:apply, {mod, fun, args}}` tuple."
  def transform_mfa_tuple({:apply, {m,f,a}}), do: apply(m,f,a)

  
  @doc """
  Recognizer for system tuples of forms:
  - `{:system, "VAR"}`
  - `{:system, "VAR", default_value}`
  - `{:system, "VAR", {String, :to_integer}}`
  - `{:system, "VAR", default_value, {String, :to_integer}}`
  Returns `true` when it matches one, `false` otherwise.
  """
  def recognize_system_tuple({:system, ""<>_k}),           do: true
  def recognize_system_tuple({:system, ""<>_k, _default}), do: true
  def recognize_system_tuple({:system, ""<>_k, _d, _mf}),  do: true
  def recognize_system_tuple(_),                               do: false

  @doc """
  Return transformed copy of recognized system tuples:
  gets from env, optionally converts it, with 
  optional default if env returned nothing.
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

  
  
    
end

