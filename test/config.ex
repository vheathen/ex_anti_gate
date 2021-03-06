defmodule ExAntiGateTest.Config do
  @moduledoc false

  def config_defaults do
    %{
        autostart: true, # Start ExAntiGate process on application start
        http_client: HTTPoisonTest,
#        http_client: HTTPoison, # http client - change for testing proposes only

        # ############################# task options #####################################

#        api_key: nil,
        api_host: "https://api.anti-captcha.com",
        language_pool: "en",             # "en" (default) - english queue,
                                         # "rn" - Russian, Ukrainian, Belorussian, Kazakh language group
        result_request_interval: 10_000, # result request first attemt interval, in milliseconds
        result_retry_interval: 2_000,     # delay between captcha status checks, in milliseconds
        no_slot_retry_interval: 5_000,   # delay between retries to catch a free slot to proceed captcha, in milliseconds
        no_slot_max_retries: 0,          # number of retries to catch a free slot,
                                         # 0 - until (max_timeout - result_request_inteval) milliseconds gone
        max_timeout: 120_000,            # captcha recognition maximum timeout;
                                         # the result value must be read during this period
        push: false
    }
  end

  def runtime_defaults do
    %{
      # from task_default
      from: nil,
      timer: nil,
      type: nil,
      task: nil,
      no_slot_attempts: 0,
      status: :waiting,
      response: :none,
      api_task_id: nil,
      push: false
    }
  end

  def config_defaults_reduced do
    Map.merge(config_defaults(), reduced_timeouts())
  end

  def defaults_reduced do
    Map.merge(defaults(), reduced_timeouts())
  end

  def timefields do
    [:result_request_interval,
     :result_retry_interval,
     :no_slot_retry_interval,
     :max_timeout]
  end

  def reduced_timeouts do
    config_defaults()
    |> Enum.map(fn({k, v}) ->
                  v = if k in timefields(), do: Integer.floor_div(v, 1000), else: v
                  {k, v}
                end)
    |> Enum.into(%{})

  end

  def defaults do
    Map.merge(config_defaults(), runtime_defaults())
  end

end
