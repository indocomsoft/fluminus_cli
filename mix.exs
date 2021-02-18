defmodule FluminusCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :fluminus_cli,
      version: "0.5.1",
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
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :race_conditions, :underspecs, :unmatched_returns]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mix]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fluminus, "~> 2.2"},
      {:gen_retry, github: "indocomsoft/gen_retry", branch: "stacktrace"},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:credo, "~> 1.5.0", only: :test, runtime: false},
      {:dialyxir, "~> 1.1.0", only: :test, runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
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
