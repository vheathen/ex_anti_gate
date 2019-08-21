defmodule ExAntiGateRealTest do
  use ExUnit.Case, async: true

  alias ExAntiGateTest.ImageList

  @moduletag :real_tests

  setup_all do
    Application.put_env(:ex_anti_gate, :language_pool, "rn")
    Application.put_env(:ex_anti_gate, :min_length, 5)
    Application.put_env(:ex_anti_gate, :max_length, 5)
    Application.put_env(:ex_anti_gate, :max_timeout, 240_000)

    :ok
  end

  test "image 0 with push" do

    image = ImageList.get_image(0).image
    code = ImageList.get_image(0).code

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: image, push: true)

    assert_receive {:ex_anti_gate_result, {:ready, ^task_uuid, %{"solution" => %{"text" => ^code}}}},
                   Application.get_env(:ex_anti_gate, :max_timeout) + 100
  end

  test "image 1 with get_task_result" do

    image = ImageList.get_image(1).image
    code = ImageList.get_image(1).code

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: image)

    :timer.sleep 15_000

    # {status, result} = ExAntiGate.get_task_result(task_uuid)

    Stream.unfold(ExAntiGate.get_task_result(task_uuid), fn
      {:processing, _} ->
        Process.sleep(2_000)
        :processing

      {:ready, result} ->
        assert get_in(result, ["solution", "text"]) == code
        nil
    end)

  end

  test "image 2 without push" do

    image = ImageList.get_image(2).image
    code = ImageList.get_image(2).code

    task_uuid = ExAntiGate.solve_captcha("ImageToTextTask", body: image)

    :timer.sleep 15_000

    Stream.unfold(ExAntiGate.get_task(task_uuid), fn
      %{status: :processing} = _task ->
        Process.sleep(2_000)
        :processing

      %{status: :ready} = task ->
        assert get_in(task, [:response, "solution", "text"]) == code
        nil
    end)

  end

  test "NoCaptchaProxylessTask with push" do
    opts = [
      websiteURL: "https://patrickhlauke.github.io/recaptcha/",
      websiteKey: "6Ld2sf4SAAAAAKSgzs0Q13IZhY02Pyo31S2jgOB5"
    ]

    task_uuid = ExAntiGate.solve_captcha("NoCaptchaTaskProxyless", [{:push, true} | opts])

    assert_receive {:ex_anti_gate_result, {:ready, ^task_uuid, %{"solution" => %{"gRecaptchaResponse" => g_recaptcha}}}},
                   Application.get_env(:ex_anti_gate, :max_timeout) + 100

    assert is_binary(g_recaptcha)
    assert byte_size(g_recaptcha) > 10
  end

end
