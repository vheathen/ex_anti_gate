defmodule ExAntiGateTest do
  use ExUnit.Case, async: false

  import Mock
  require Logger

  @config_defaults %{
    autostart: true, # Start ExAntiGate process on application start

    # ############################# task options #####################################

    api_host: "https://api.anti-captcha.com",
    language_pool: "en",             # "en" (default) - english queue,
                                     # "rn" - Russian, Ukrainian, Belorussian, Kazakh language group
    result_request_interval: 10_000, # result request first attemt interval, in milliseconds
    result_retry_inteval: 2_000,     # delay between captcha status checks, in milliseconds
    no_slot_retry_interval: 5_000,   # delay between retries to catch a free slot to proceed captcha, in milliseconds
    no_slot_max_retries: 0,          # number of retries to catch a free slot,
                                     # 0 - until (max_timeout - result_request_inteval) milliseconds gone
    max_timeout: 120_000,            # captcha recognition\retries maximum timeout
    phrase: false,                   # does captcha have one or more spaces
    case: false,                     # captcha is case sensetive
    numeric: 0,                      # 0 - any symbols
                                     # 1 - captcha has digits only
                                     # 2 - captcha has any symbols EXCEPT digits
    math: false,                     # captcha is a math equation and it's necessary to solve it and enter result
    min_length: 0,                   # 0 - has no limits
                                     # > 0 - an integer sets minimum captcha length
    max_length: 0, # 0 - has no limits
                   # > 0 - an integer sets maximum captcha length
    push: false    # do not reply to the sender by default (wait for a result request)
  }

  @runtime_defaults %{
    # from task_default
    from: nil,
    created_at: nil,
    updated_at: nil,
    type: nil,
    image: nil,
    status: :waiting,
    result: :none
  }

  @reduced_timeouts %{
    result_request_interval: 10,
    result_retry_inteval: 2,
    no_slot_retry_interval: 5,
    max_timeout: 120,
  }

  @config_defaults_reduced Map.merge(@config_defaults, @reduced_timeouts)

  @defaults Map.merge(@config_defaults, @runtime_defaults)

  @defaults_reduced Map.merge(@defaults, @reduced_timeouts)

  doctest ExAntiGate

  setup_all do
    Enum.each(@config_defaults_reduced, fn({k, v}) ->
      Application.put_env(:ex_anti_gate, k, v)
    end)

    :ok
  end

  test "must have task uuid returned" do
    uuid = ExAntiGate.solve_text_task("")
    assert uuid != ""
  end

  test "defaults must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring")
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == Map.merge(@defaults_reduced, %{image: "somestring"})
  end

  test "options changes must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring", phrase: true)
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == Map.merge(@defaults_reduced, %{image: "somestring", phrase: true})
  end

  test "timestamps must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring")
    task = ExAntiGate.get_task(task_uuid)

    assert is_integer(task.created_at)
    assert is_integer(task.updated_at)
  end

  test "type must be 'ImageToTextTask' in case of text captcha solving" do
    task_uuid = ExAntiGate.solve_text_task("somestring")
    assert ExAntiGate.get_task(task_uuid)[:type] == "ImageToTextTask"
  end

  test "try to receive a reply" do
    task_uuid = ExAntiGate.solve_text_task("", push: true)
    assert_receive {:"$gen_cast", {:antigate_result, ^task_uuid}}, Application.get_env(:ex_anti_gate, :max_timeout) + 10
  end

  test "must have not a reply with default settings" do
    uuid = ExAntiGate.solve_text_task("")
    refute_receive {:"$gen_cast", {:antigate_result, ^uuid}}, Application.get_env(:ex_anti_gate, :max_timeout) + 10
  end

  defp nilify_task_fields(task) do
    task
    |> Map.put(:from, nil)
    |> Map.put(:type, nil)
    |> Map.put(:created_at, nil)
    |> Map.put(:updated_at, nil)
    |> Map.delete(:api_key) # we don't want to have it in test
  end

end
