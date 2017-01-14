defmodule DeferredConfigTest do
  use ExUnit.Case
  doctest DeferredConfig

  @app :lazy_cfg_test_appname

  setup do
    delete_all_env(@app)
    env = %{"PORT" => "4000"}
    system_transform = fn
      {:system, k}            -> Map.get(env, k)
      {:system, k, {m, f}}    -> apply m, f, [Map.get(env, k)]
      {:system, k, d}         -> Map.get(env, k, d)
      {:system, k, d, {m, f}} -> apply( m, f, [Map.get(env, k)]) || d
    end
    [system_transform: system_transform]
  end

  test "basic config", %{system_transform: transform} do
    cfg = [
      port1: {:system, "PORT"},
      port2: {:system, "PORT", "1111"},
      port3: {:system, "FAIL", "1111"},
      port4: {:system, "PORT", {String, :to_integer}},
      port5: {:system, "PORT", 3000, {String, :to_integer}},
    ]
    DeferredConfig.walk_cfg(
      @app,
      cfg,
      &DeferredConfig.recognize_system_tuple/1,
      transform
    )
    actual = Application.get_all_env @app
    assert actual[:port1] == "4000"
    assert actual[:port2] == "4000"
    assert actual[:port3] == "1111"
    assert actual[:port4] == 4000
    assert actual[:port5] == 4000
  end


  defp delete_all_env(app) do
    app
    |> Application.get_all_env
    |> Enum.each(fn {k, v} ->
      Application.delete_env( app, k )
    end)
  end
  
end
