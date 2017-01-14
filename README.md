# DeferredConfig

Seamless runtime config with one line of code.
No 'mappings,' no special access methods.
Support the common "system tuples" pattern effortlessly.

- Aren't there some solutions to this already?

  There's more detail below, but
  **TL;DR:** `REPLACE_OS_VARS` is string-only and release-only,
  and `{:system, ...}` support among libraries is inconsistent
  and easy to get wrong in ways that bite your users
  come release time. This library tries to make it easier
  to do the right thing.

  Other libraries do, too, but they
  add special config accessor functions, and/or their
  own config files or mappings. We don't need to,
  because we rely on just doing a replacing walk
  of an app's config, kicked off by a line
  of code added during `Application.start/2`.

# Usage

In mix.exs,

    defp deps, do: [{:system_tuples, "~> 0.1.0"}]

Then, in your application startup, add the following line:

    defmodule Mine.Application do
      ...
      def start(_type, _args) do

        :mine |> DeferredConfig.populate_system_tuples

        ...
      end
    end

Where the app name is `:mine`.

Now, you and users of your app can configure
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

**Accessing config does not change.** If you used
`Application.get_env(:mine, :port1)` before, that will
keep working.

Since you can use arbitrary transformation functions,
you can do advanced transformations if you need to:

    # lib/mine/ip.ex
    defmodule Mine.Ip do
      @doc ":inet uses `{0,0,0,0}` for ipv4 addrs"
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

If you need even more control (say, the
source of your config isn't the system env, but a file
in a directory), you can use the deferred MFA (module, function,
arguments) form:

    config :mine, api_key: {:apply, {File, :read!, ["k.txt"]}}

If you have another use case that this doesn't cover, 
please file an issue or reach out to github.com/mrluc

### Limitations

Note that this only applies to **one OTP app's config.**
We can't (and shouldn't try to) monkey-patch every app's 
config; they all start up at different times.


# Why do we need something like this?

Mix configs don't always work like users would
like with releases, whether built with relx, exrm, 
distillery, or something else.

There are 3 approaches to address:

1. `REPLACE_OS_VARS` for releases
2. `{:system, ...}` tuples
3. Other runtime config libraries


#### 1. `REPLACE_OS_VARS` is for releases only

The best-supported method
of injecting run-time configuration -- running the release
with `REPLACE_OS_VARS` or `RELX_REPLACE_OS_VARS`, supported 
by `distillery`, `relx` and `exrm` -- will result in 
config like the following:

    config :my_app, field: "${SOME_VAR}"

That works in all config, for all apps, even if the app doesn't
do anything particular to support it ... but
  
  - *only when built as a release*, and
  - only for string values.

Neither is a show-stopper *by any means*, but it's a small
complication ... shared by hundreds, or thousands, of
libraries.
  
#### 2. `{:system, ...}` tuples have inconsistent support
  
Apps that want to allow
run-time configuration from Mix configs (which you could
argue is 'all of them') should be configurable
with lazy values, which can be filled **on startup of 
that application, before they are used**.

What should those lazy values look like? Many libraries have 
settled on so-called 'system tuples', like:

    config :someapp, 
      field: {:system, "ENV_VAR_NAME", "default value"}

**The downside**: that approach requires every
library author to recognize and support that kind
of tuple. 

Some big libraries do! However, it can be a pain to add 
support for that kind of config consistently, converting 
data types appropriately, for all configurable options in 
your app. This library just automates that pattern.

#### 3. Other runtime config libs use special config files and/or access methods

There are several other runtime config libs, but
they all introduce their own methods for accessing
Application config, and other complexity as well
(special mappings, config files, etc).
We simply do a replacing walk on the app's config
at startup.
