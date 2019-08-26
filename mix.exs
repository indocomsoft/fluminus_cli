defmodule FluminusCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :fluminus_cli,
      version: "0.4.3",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/indocomsoft/fluminus_cli",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      package: package(),
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fluminus, "~> 1.3"},
      {:jason, "~> 1.1"},
      {:gen_retry, "~> 1.2.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A CLI client for the reverse-engineered LumiNUS API (https://luminus.nus.edu.sg)"
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/indocomsoft/fluminus_cli"}
    ]
  end
end
