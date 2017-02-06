defmodule ExAntiGate.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_anti_gate,
     version: "0.1.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     name: "ExAntiGate",
     source_url: "https://github.com/vheathen/ex_anti_gate",
     descirption: "Elixir AntiGate.com (anti-captcha.com) captcha solving service API client",
     package: [
             name: :ex_anti_gate,
             files: ["lib", "config/config.exs", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
             maintainers: ["Vladimir Drobyshevskiy"],
             licenses: ["MIT"],
             links: %{ "GitHub" => "https://github.com/vheathen/ex_anti_gate" },
           ]
     ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [ mod: {ExAntiGate.App, []},
      extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.11.0"},
      {:ecto, "~> 2.1", runtime: false},
      {:poison, "~> 3.0"},
      {:ex_doc, "~> 0.14", only: :dev},
      {:dogma, "~> 0.0", only: [:test]},
      {:mix_test_watch, "~> 0.0", runtime: false, only: [:dev]},
    ]
  end
end
