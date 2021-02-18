defmodule DeferredConfigTest do
  use ExUnit.Case
  doctest DeferredConfig

  @app :lazy_cfg_test_appname

  defmodule MyMod do
    def get_my_key("" <> _bin), do: "your key is 1234. write it down."
  end

  setup do
    delete_all_env(@app)
    # give each test a fake env that looks like this
    env = %{"PORT" => "4000"}

    system_transform = fn
      {:system, k} -> Map.get(env, k)
      {:system, k, {m, f}} -> apply(m, f, [Map.get(env, k)])
      {:system, k, d} -> Map.get(env, k, d)
      {:system, k, d, {m, f}} -> apply(m, f, [Map.get(env, k)]) || d
    end

    # our mock stack -- only changes env var retrieval
    transforms = [
      {&DeferredConfig.recognize_system_tuple/1, system_transform},
      {&DeferredConfig.recognize_mfa_tuple/1, &DeferredConfig.transform_mfa_tuple/1}
    ]

    [transforms: transforms, system_transform: system_transform]
  end

  test "system tuples support", %{system_transform: transform} do
    cfg = [
      port1: {:system, "PORT"},
      port2: {:system, "PORT", "1111"},
      port3: {:system, "FAIL", "1111"},
      port4: {:system, "PORT", {String, :to_integer}},
      port5: [{:system, "PORT", 3000, {String, :to_integer}}]
    ]

    actual =
      cfg
      |> DeferredConfig.transform_cfg([
        {&DeferredConfig.recognize_system_tuple/1, transform}
      ])

    assert actual[:port1] == "4000"
    assert actual[:port2] == "4000"
    assert actual[:port3] == "1111"
    assert actual[:port4] == 4000
    assert actual[:port5] == [4000]
    actual |> DeferredConfig.apply_transformed_cfg!(@app)

    actual = Application.get_all_env(@app)
    assert actual[:port1] == "4000"
    assert actual[:port2] == "4000"
    assert actual[:port3] == "1111"
    assert actual[:port4] == 4000
    assert actual[:port5] == [4000]
  end

  test "non-existent tuple values are handled" do
    r = DeferredConfig.transform_cfg(key: {:system, "ASDF"})
    assert r[:key] == nil
  end

  test "readme sys/mfa example", %{transforms: transforms} do
    readme_example = [
      # even inside nested data
      http: %{
        # the common 'system tuple' pattern is fully supported
        port: {:system, "PORT", {String, :to_integer}}
      },
      # more general 'mfa tuple' pattern is also supported
      key: {:apply, {MyMod, :get_my_key, ["arg"]}}
    ]

    actual =
      readme_example
      |> DeferredConfig.transform_cfg(transforms)

    assert "your key is" <> _ = actual[:key]
    assert actual[:http][:port] == 4000
  end

  defp delete_all_env(app) do
    app
    |> Application.get_all_env()
    |> Enum.each(fn {k, _v} ->
      Application.delete_env(app, k)
    end)
  end
end
