defmodule ExAntiGate.App do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    unless is_nil(System.get_env("EX_ANTI_GATE_API_KEY")) do
      Application.put_env(:ex_anti_gate, :api_key, System.get_env("EX_ANTI_GATE_API_KEY"))
    end

    if is_nil(Application.get_env(:ex_anti_gate, :api_key)) do
      Logger.error "ExAntiGate: api_key must to be set. Please check documetation."
      Process.exit(self(), :kill)
    end

    if Application.get_env(:ex_anti_gate, :autostart) do
      # Start the supervision tree
      ExAntiGate.Supervisor.start_link
    end

  end

end
