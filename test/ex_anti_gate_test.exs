defmodule ExAntiGateTest do
  use ExUnit.Case, async: false

  require Logger

  import ExAntiGateTest.Config

  doctest ExAntiGate

  setup do
    Enum.each(config_defaults_reduced(), fn({k, v}) ->
      Application.put_env(:ex_anti_gate, k, v)
    end)

    :ok
  end

  test "must have task uuid returned" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")
    assert task_uuid != ""
  end

  test "defaults must be set" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == defaults_reduced()
  end

  test "options changes must be set" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", phrase: true)
    task = ExAntiGate.get_task(task_uuid)

    assert nilify_task_fields(task) == defaults_reduced()
  end

  test "type must be 'ImageToTextTask' in case of text captcha solving" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")
    assert Keyword.get(ExAntiGate.get_task(task_uuid).task, :type) == "ImageToTextTask"
  end

  test "timer must be set" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")
    task = ExAntiGate.get_task(task_uuid)

    refute is_nil(task.timer)
  end

  test "task must not be available after max timeout" do
    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")
    :timer.sleep defaults_reduced().max_timeout + 10
    task = ExAntiGate.get_task(task_uuid)

    assert is_nil(task)
  end

  test "must receive an error after max timeout in case of push: true" do
    defmodule HTTPoisonTestTimeout do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 5_000
      end
    end

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", push: true, http_client: HTTPoisonTestTimeout)
    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -2, "ERROR_API_TIMEOUT", "Maximum timeout reached, task interrupted."}}, defaults_reduced().max_timeout + 50
    assert is_nil ExAntiGate.get_task(task_uuid)
  end

  # 'noun' mocking: http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/
  test "task id must be set after initial API call" do

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", http_client: HTTPoisonTest)

    :timer.sleep 100

    assert ExAntiGate.get_task(task_uuid)[:api_task_id] == 1234567
  end

  test "must receive an error in case of the API error" do
    defmodule HTTPoisonTestTaskAbsent do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 50
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":22,"errorCode":"ERROR_TASK_ABSENT","errorDescription":"Task property is empty or not set. Please refer to API v2 documentation."}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", http_client: HTTPoisonTestTaskAbsent, push: true)

    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, 22, "ERROR_TASK_ABSENT", "Task property is empty or not set. Please refer to API v2 documentation."}}, defaults_reduced().max_timeout + 10
  end

  test "must retry if there is no free slot available" do
    defmodule HTTPoisonTestNoSlot do
      def post("https://api.anti-captcha.com/createTask", _request, _headers) do
        :timer.sleep 1
        { :ok,
          %HTTPoison.Response{  body: ~S({"errorId":2,"errorCode":"ERROR_NO_SLOT_AVAILABLE","errorDescription":"Doesn't matter"}),
                                headers: ExAntiGateTest.httpoison_headers(),
                                status_code: 200}
        }
      end
    end

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", http_client: HTTPoisonTestNoSlot, no_slot_max_retries: 10, push: true)

    :timer.sleep 50

    task = ExAntiGate.get_task(task_uuid)

    assert task.api_task_id == nil
    refute task.no_slot_attempts == 0

    assert_receive {:ex_anti_gate_result, {:error, ^task_uuid, -3, "ERROR_NO_SLOT_MAX_RETRIES", "Maximum attempts to catch free slot reached, task interrupted."}}, defaults_reduced().max_timeout + 50

  end

  describe "Tasks" do
    test "captcha must be solved in the end" do

      task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")

      :timer.sleep 100

      task = ExAntiGate.get_task(task_uuid)

      assert task.status == :ready
      assert task.response == HTTPoisonTest.response() |> Jason.decode!()

    end

    test "captcha must be solved in the end and get_task_result must work" do
      task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring")

      :timer.sleep 100

      {status, result} = ExAntiGate.get_task_result(task_uuid)

      assert status == :ready
      assert result == HTTPoisonTest.response() |> Jason.decode!()

    end

    test "captcha must be solved in the end and push must work" do
      task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: "somestring", push: true)

      response = HTTPoisonTest.response() |> Jason.decode!()
      assert_receive {:ex_anti_gate_result, {:ready, ^task_uuid, ^response}}, defaults_reduced().max_timeout + 20
    end

    test "NoCaptchaTask should generate a correct task" do
      opts =
        [
          type: "NoCaptchaTask",
          websiteURL: "http:/some.url.com",
          websiteKey: UUID.uuid4(),
          # websiteSToken: nil,
          proxyType: "http",
          proxyAddress: "127.0.0.1",
          proxyPort: 8080,
          proxyLogin: "login",
          proxyPassword: "password",
          userAgent: "Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19",
          cookies: "cookiename1=cookievalue1; cookiename2=cookievalue2",
          # isInvisible: nil
        ]

        task_uuid = ExAntiGate.solve_captcha("NoCaptchaTask", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

    test "NoCaptchaTaskProxyless should generate a correct task" do
      opts =
        [
          type: "NoCaptchaTaskProxyless",
          websiteURL: "http:/some.url.com",
          websiteKey: UUID.uuid4(),
          websiteSToken: UUID.uuid4()
        ]

        task_uuid = ExAntiGate.solve_captcha("NoCaptchaTaskProxyless", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

    test "RecaptchaV3TaskProxyless should generate a correct task" do
      opts =
        [
          type: "RecaptchaV3TaskProxyless",
          websiteURL: "http:/some.url.com",
          websiteKey: UUID.uuid4(),
          minScore: 0.3,
          pageAction: 'login_test'
        ]

      task_uuid = ExAntiGate.solve_captcha("RecaptchaV3TaskProxyless", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

    test "FunCaptchaTask should generate a correct task" do
      opts =
        [
          type: "FunCaptchaTask",
          websiteURL: "http:/some.url.com",
          funcaptchaApiJSSubdomain: "http:/some_domain.com",
          websitePublicKey: UUID.uuid4(),
          proxyType: "http",
          proxyAddress: "127.0.0.1",
          proxyPort: 8080,
          proxyLogin: "login",
          proxyPassword: "password",
          userAgent: "Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19",
          cookies: "cookiename1=cookievalue1; cookiename2=cookievalue2"
        ]

        task_uuid = ExAntiGate.solve_captcha("FunCaptchaTask", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

    test "FunCaptchaTaskProxyless should generate a correct task" do
      opts =
        [
          type: "FunCaptchaTaskProxyless",
          websiteURL: "http:/some.url.com",
          funcaptchaApiJSSubdomain: "http:/some_domain.com",
          websitePublicKey: UUID.uuid4()
        ]

        task_uuid = ExAntiGate.solve_captcha("FunCaptchaTaskProxyless", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

    test "SquareNetTextTask should generate a correct task" do
      opts =
        [
          type: "SquareNetTextTask",
          body: "someimagestring",
          objectName: "banana",
          rowsCount: 3,
          columnsCount: 3
        ]

        task_uuid = ExAntiGate.solve_captcha("SquareNetTextTask", opts |> Keyword.delete(:type))

      assert opts == ExAntiGate.get_task(task_uuid).task
    end

  end

  defp nilify_task_fields(task) do
    task
    |> Map.put(:from, nil)
    |> Map.put(:type, nil)
    |> Map.put(:timer, nil)
    |> Map.put(:task, nil)
    |> Map.delete(:api_key) # we don't want to have it in test
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
