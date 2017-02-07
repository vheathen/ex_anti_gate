defmodule ExAntiGate.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    unless is_nil(System.get_env("EX_ANTI_GATE_API_KEY")) do
      Application.put_env(:ex_anti_gate, :api_key, System.get_env("EX_ANTI_GATE_API_KEY"))
    end

    if is_nil(Application.get_env(:ex_anti_gate, :api_key)) do
      raise ArgumentError, """
      There was no API_KEY set for the ExAntiGate API Client.

      You MUST provide API_KEY in config files as:

          config :ex_anti_gate,
              api_key: "yourlongapikey"

      or via a system environment variable `EX_ANTI_GATE_API_KEY`.
      The last option has preference over the one set on configuration file.

      Please check documentation at https://hexdocs.pm/ex_anti_gate
      """
    end

    children =
      if Application.get_env(:ex_anti_gate, :autostart) do
        # Define workers and child supervisors to be supervised
        [
          # Starts a worker by calling: ExAntiGate.Worker.start_link(arg1, arg2, arg3)
          # worker(ExAntiGate.Worker, [arg1, arg2, arg3]),
          worker(ExAntiGate, [])
        ]
      else
        []
      end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExAntiGate.Supervisor]
    Supervisor.start_link(children, opts)

  end

end
