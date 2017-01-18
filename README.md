## Deferred Config

Seamless runtime config with one line of code. In
your application's `start/2` method, call:

```elixir
DeferredConfig.populate(:otp_app_name)
```

And now you and users of your application or library
will be able to write config that is deferred to
runtime, like the following:

```elixir
config :otp_app_name,
  http: %{ # nested config is ok
    # common 'system tuple' pattern is fully supported
    port: {:system, "PORT", {String, :to_integer}}
  },
  # more general 'mfa tuple' pattern is also supported
  secret_key: {:apply, {MyKey, :fetch, ["arg"]}}
```

That's it.

- No 'mappings,' no special access methods -- just
  keep using `Application.get_env/2`.
- Works for arbitrarily nested config.
- Works just as well when run with mix as it does
  in releases built with `:distillery`, `:exrm`,
  or `:relx`.
- Lets library authors support the
  common "system tuples" pattern *effortlessly.*

**Why this library?**

See '[Rationale](#rationale)' for more detail. But
**TLDR:** `REPLACE_OS_VARS` is string-only and
release-only, and `{:system, ...}` support among
libraries is inconsistent and easy to get wrong in
ways that bite your users come release time -- in
other words, until now it's been a burden on
library authors. This library tries to make it
1 LOC to do the right thing.

There are other libraries to manage runtime config
(see list at end of readme) but using them is harder
as they add things -- like special config accessor functions,
and/or their own config files, or mappings, or DSLs. We don't
need to, because we rely on a `ReplacingWalk`
of an app's config during `Application.start/2`, and
the only DSL are configuration patterns sourced from
the community, like system and mfa tuples.


## Usage

In mix.exs,

```elixir
defp deps, do: [{:deferred_config, "~> 0.1.0"}]
```

Then, in your application startup, add the following line:

```elixir
defmodule Mine.Application do
  ...
  def start(_type, _args) do

    DeferredConfig.populate(:mine)  # <---

    ...
  end
end
```

Where the app name is `:mine`.

Now, you and users of your app can configure
as follows, and it'll work -- regardless of if they're
running it from iex, or a release with env vars set:

```elixir
config :mine, 

  # string from env var, or `nil` if missing.
  port1: {:system, "PORT"},

  # string from env var |> integer; `nil` if missing.
  port2: {:system, "PORT", {String, :to_integer}},

  # string from env var, or "4000" as default.
  port3: {:system, "PORT", "4000"},

  # converts env var to integer, or 4000 as default.
  port4: {:system, "PORT", 4000, {String, :to_integer}}
```

## Features

**Accessing config does not change.** If you used
`Application.get_env(:mine, :port1)` before, that will
keep working.

Since you can use arbitrary transformation functions,
**you can do advanced transformations** if you need to:

```elixir
# --- lib/mine/ip.ex
defmodule Mine.Ip do
  @doc ":inet uses `{0,0,0,0}` for ipv4 addrs"
  def str2ip(str) do
    case :inet_parse:address(str) do
      {:ok, ip = {_, _, _, _}} -> ip
      {:error, _}              -> nil
    end
  end
end

# --- config.exs 
config :my_app,
  port: {:system, "MY_IP", {127,0,0,1}, {Mine.Ip, :str2ip}
```

If you need even more control -- say, the
source of your config isn't the system env, but a file
in a directory, which is more secure in some use
cases -- you can use the deferred MFA (module, function,
arguments) form:

```elixir
config :mine,
  api_key: {:apply, {File, :read!, ["k.txt"]}}
```

**Nested and arbitrary config** should work.

**Can be extended** to recognize and transform
other kinds of config as well (`DeferredConfig.populate/2`),
ie if there's a pattern like 'system tuples' that you
wanted to support, and `{:apply, mfa}` was bad UX.

If you have another use case that this doesn't cover, 
please file an issue or reach out to github.com/mrluc

### Limitations

Note that this only applies to **one OTP app's config.**
We can't (and shouldn't try to) monkey-patch every app's 
config; they all start up at different times.

This limitation applies to all approaches to runtime
config except `REPLACE_OS_VARS`.


## Rationale

Mix configs don't always work like users would
like when they build releases, whether with relx, exrm, 
distillery, or something else.

There are 3 approaches we'll look at to identify pain points:

1. `REPLACE_OS_VARS` for releases
2. `{:system, ...}` tuples for deferred config
3. Other runtime config libraries


### 1) REPLACE_OS_VARS is for releases only

The best-supported method
of injecting run-time configuration -- running the release
with `REPLACE_OS_VARS` or `RELX_REPLACE_OS_VARS`, supported 
by `distillery`, `relx` and `exrm` -- will result in 
config like the following:

    config :my_app, field: "${SOME_VAR}"

That works in **all your config, for all apps you configure**,
even if the app doesn't do anything particular to support it.

Drawbacks of `REPLACE_OS_VARS`
  
  - It only works when running a release.
    Otherwise, your `DB_URL` will literally be `"${DB_URL}"`.
  - It only gives you string values. Some libs will require
    that eg `PORT` be a number.

Neither is a show-stopper *by any means*, but it's
a small complication ... shared users of thousands of
libraries.
  
### 2) `{:system, ...}` tuples have inconsistent support
  
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
your app. (A small pain, spread over many libraries).
This library automates that pattern.


### 3) Other runtime config libs use special config files and/or access methods

There are many other libs for config, most of which also
deal with runtime config:

- [:confex](https://hexdocs.pm/confex)
- [:flasked](https://hexdocs.pm/flasked)
- [:env_config](https://hexdocs.pm/env_config)
- [:config_ext](https://hexdocs.pm/config_ext)
- [libex_config](https://hex.pm/packages/libex_config)
- [:configparser](https://hexdocs.pm/configparser_ex)
- [:config](https://hexdocs.pm/config)
- [:spellbook](https://hex.pm/packages/spellbook)

They solve a wide variety of config-related problems.

However, these **all** introduce their own methods for
accessing Application config, and other complexity
as well (mappings, config files, etc).

We avoid that, by doing a replacing walk on the
app's config at startup.


## 'When should I REPLACE_OS_VARS?'

Always, but not always because of app config!

For injecting config, it has the limitations
mentioned above in 'Rationale.'

- For config: **if** you need to configure many libraries that don't
support deferred config, **and** what you want to configure
can be a string (`DB_URL`, for instance) ... in
that case, maybe a release-only config is a good option.

But you should probably use `REPLACE_OS_VARS`
(or `RELX_REPLACE_OS_VARS`), because it also
allows **interpolation in `vm.args`**.

- That lets you drive node short/longnames in releases with env vars.
  Which can be important when eg you don't know the node
  IP for a release at compile-time.
- It's nice that the same approach for vm.args templating
  works across release builders.

