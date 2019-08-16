defmodule ExAntiGate.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_anti_gate,
     version: "0.3.4",
     elixir: "~> 1.7",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     name: "ExAntiGate",
     source_url: "https://github.com/vheathen/ex_anti_gate",
     description: "Elixir AntiGate.com (anti-captcha.com) captcha solving service API client",
     package: [
             name: :ex_anti_gate,
             files: ["lib", "mix.exs", "README*", "LICENSE*"],
             maintainers: ["Vladimir Drobyshevskiy"],
             licenses: ["MIT"],
             links: %{ "GitHub" => "https://github.com/vheathen/ex_anti_gate" },
           ]
     ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_),     do: ["lib"]

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [ mod: {ExAntiGate.Application, []},
      extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, "~> 1.5"},
      {:elixir_uuid, "~> 1.2.0"},
      {:jason, "~> 1.0"},
      {:ex_doc, "~> 0.21.1", only: :dev},
      {:mix_test_watch, "~> 0.9", runtime: false, only: [:dev]},
    ]
  end
end
