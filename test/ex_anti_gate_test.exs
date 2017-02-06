defmodule ExAntiGateTest do
  use ExUnit.Case, async: false

  require Logger

  alias ExAntiGateTest.ImageList

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
    timer: nil,
    type: nil,
    image: nil,
    no_slot_attempts: 0,
    status: :waiting,
    result: :none,
    api_task_id: nil
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

  setup do
    Enum.each(@config_defaults_reduced, fn({k, v}) ->
      Application.put_env(:ex_anti_gate, k, v)
    end)

    :ok
  end

  test "must have task uuid returned" do
    uuid = ExAntiGate.solve_text_task("", fake: true)
    assert uuid != ""
  end

  test "defaults must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring", fake: true)
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == Map.merge(@defaults_reduced, %{image: "somestring", timer: nil})
  end

  test "options changes must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring", phrase: true, fake: true)
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == Map.merge(@defaults_reduced, %{image: "somestring", phrase: true})
  end

  test "type must be 'ImageToTextTask' in case of text captcha solving" do
    task_uuid = ExAntiGate.solve_text_task("somestring", fake: true)
    assert ExAntiGate.get_task(task_uuid)[:type] == "ImageToTextTask"
  end

  test "timer must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring", fake: true)
    task = ExAntiGate.get_task(task_uuid)

    refute is_nil(task.timer)
  end

  test "task must not be available after max timeout" do
    task_uuid = ExAntiGate.solve_text_task("somestring", fake: true)
    :timer.sleep @defaults_reduced.max_timeout + 10
    task = ExAntiGate.get_task(task_uuid)

    assert is_nil(task)
  end

  test "must receive an error after max timeout in case of push: true" do
    task_uuid = ExAntiGate.solve_text_task("", push: true, fake: true)
    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -2, "ERROR_API_TIMEOUT", "Maximum timeout reached, task interrupted"}}, @defaults_reduced.max_timeout + 10
  end

  test "task id must be set after initial API call" do
    defmodule HTTPoisonTest do
      def post(_url, _request, _headers) do
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest)

    :timer.sleep 50

    assert ExAntiGate.get_task(task_uuid)[:api_task_id] == 1234567
  end

  test "must receive an error in case of the API error" do
    defmodule HTTPoisonTest do
      def post(_url, _request, _headers) do
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":22,"errorCode":"ERROR_TASK_ABSENT","errorDescription":"Task property is empty or not set. Please refer to API v2 documentation."}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest, push: true)

    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, 22, "ERROR_TASK_ABSENT", "Task property is empty or not set. Please refer to API v2 documentation."}}, @defaults_reduced.max_timeout + 10
  end

  test "must retry if there is no free slot available" do
    defmodule HTTPoisonTest do
      def post(_url, _request, _headers) do
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":2,"errorCode":"ERROR_NO_SLOT_AVAILABLE","errorDescription":"Doesn't matter"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest)

    task = ExAntiGate.get_task(task_uuid)

    :timer.sleep 50

    assert task.api_task_id == nil
    refute task.no_slot_attempts == 0

  end

  defp nilify_task_fields(task) do
    task
    |> Map.put(:from, nil)
    |> Map.put(:type, nil)
    |> Map.put(:timer, nil)
    |> Map.delete(:api_key) # we don't want to have it in test
    |> Map.delete(:fake)
    |> Map.delete(:http_client)
  end

  def httpoison_headers do
    [  {"Server", "nginx/1.10.2"},
       {"Date", "Sun, 05 Feb 2017 16:26:54 GMT"},
       {"Content-Type", "application/json; charset=utf-8"},
       {"Transfer-Encoding", "chunked"},
       {"Connection", "keep-alive"},
       {"X-Powered-By", "PHP/5.4.45"},
       {"Access-Control-Allow-Origin", "*"},
       {"Access-Control-Allow-Headers",
        "Overwrite, Destination, Content-Type, Depth, User-Agent, X-File-Size, X-Requested-With, If-Modified-Since, X-File-Name, Cache-Control"}
      ]
  end

end
