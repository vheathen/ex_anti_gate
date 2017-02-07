defmodule ExAntiGateTest do
  use ExUnit.Case, async: false

  require Logger

  import ExAntiGateTest.Config
  alias ExAntiGate.Config

  doctest ExAntiGate

  setup do
    Enum.each(config_defaults_reduced(), fn({k, v}) ->
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

    assert nilify_task_fields(task) == Map.merge(defaults_reduced(), %{image: "somestring", timer: nil})
  end

  test "options changes must be set" do
    task_uuid = ExAntiGate.solve_text_task("somestring", phrase: true, fake: true)
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == Map.merge(defaults_reduced(), %{image: "somestring", phrase: true})
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
    :timer.sleep defaults_reduced().max_timeout + 10
    task = ExAntiGate.get_task(task_uuid)

    assert is_nil(task)
  end

  test "must receive an error after max timeout in case of push: true" do
    task_uuid = ExAntiGate.solve_text_task("", push: true, fake: true)
    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -2, "ERROR_API_TIMEOUT", "Maximum timeout reached, task interrupted."}}, defaults_reduced().max_timeout + 50
    assert is_nil ExAntiGate.get_task(task_uuid)
  end

  # 'noun' mocking: http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/
  test "task id must be set after initial API call" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 40
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest)

    :timer.sleep 100

    assert ExAntiGate.get_task(task_uuid)[:api_task_id] == 1234567
  end

  test "must receive an error in case of the API error" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 50
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":22,"errorCode":"ERROR_TASK_ABSENT","errorDescription":"Task property is empty or not set. Please refer to API v2 documentation."}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest, push: true)

    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, 22, "ERROR_TASK_ABSENT", "Task property is empty or not set. Please refer to API v2 documentation."}}, defaults_reduced().max_timeout + 10
  end

  test "must retry if there is no free slot available" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 1
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":2,"errorCode":"ERROR_NO_SLOT_AVAILABLE","errorDescription":"Doesn't matter"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest, no_slot_max_retries: 10, push: true)

    :timer.sleep 50

    task = ExAntiGate.get_task(task_uuid)

    assert task.api_task_id == nil
    refute task.no_slot_attempts == 0

    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -3, "ERROR_NO_SLOT_MAX_RETRIES", "Maximum attempts to catch free slot reached, task interrupted."}}, defaults_reduced().max_timeout + 20

  end

  test "captcha must be solved in the end" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest)

    :timer.sleep 100

    task = ExAntiGate.get_task(task_uuid)

    assert task.status == :ready
    assert task.result == %{text: "deditur"}

#    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -3, "ERROR_NO_SLOT_MAX_RETRIES", "Maximum attempts to catch free slot reached, task interrupted."}}, defaults_reduced().max_timeout + 20

  end

  test "captcha must be solved in the end and get_task_result must work" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest)

    :timer.sleep 70

    {status, result} = ExAntiGate.get_task_result(task_uuid)

    assert status == :ready
    assert result == %{text: "deditur"}

  end

  test "captcha must be solved in the end and push must work" do
    defmodule HTTPoisonTest do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"taskId":1234567}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
      def post("https://api.anti-captcha.com/getTaskResult", _request, _headers) do
        :timer.sleep 10
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":0,"status":"ready","solution":{"text":"deditur","url":"http://61.39.233.233/1/147220556452507.jpg"},"cost":"0.000700","ip":"46.98.54.221","createTime":1472205564,"endTime":1472205570,"solveCount":"0"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_text_task("somestring", http_client: HTTPoisonTest, push: true)

    assert_receive {:ex_anti_gate_result, {:ready, task_uuid, %{text: "deditur"}}}, defaults_reduced().max_timeout + 20
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
