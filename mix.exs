defmodule DeferredConfig.Mixfile do
  use Mix.Project

  def project do
    [app: :deferred_config,
     version: "0.1.0",
     elixir: "~> 1.4-rc",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env != :test, # proto impl tests
     deps: deps(),

     name: "DeferredConfig",
     package: package(),
     description: description(),
     source_url: "https://github.com/mrluc/deferred_config",
     homepage_url: "https://github.com/mrluc/deferred_config",
     docs: [main: "DeferredConfig", extras: ["README.md"]]
    ]
  end

  def description do
    "Seamless runtime config. Support the 'system tuple' pattern for all your app's config with a single line of code." 
  end

  def package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Luc Fueston"],
      contributors: ["Luc Fueston"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mrluc/deferred_config",
               "Docs" => "https://hexdocs.pm/deferred_config/readme.html"}
    ]
  end
  
  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev},
     {:credo, "~> 0.5", only: [:dev, :test]}]
  end
end
