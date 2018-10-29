defmodule DeferredConfig.Mixfile do
  use Mix.Project

  def project do
    [
      app: :deferred_config,
      version: "0.1.1",
      elixir: "~> 1.4-rc",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      # proto impl tests
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      name: "DeferredConfig",
      package: package(),
      description: description(),
      source_url: "https://github.com/mrluc/deferred_config",
      homepage_url: "https://github.com/mrluc/deferred_config",
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def description do
    "Seamless runtime config with one line of code. " <>
      "No special accessors or mappings. Full support for " <>
      "'{:system...} tuple' and '{m,f,a}' runtime config patterns."
  end

  def package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Luc Fueston"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mrluc/deferred_config",
        "Docs" => "https://hexdocs.pm/deferred_config/readme.html"
      }
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev}, {:credo, "~> 0.5", only: [:dev, :test]}]
  end
end
