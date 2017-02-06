defmodule ExAntiGateRealTest do
  use ExUnit.Case, async: true

  alias ExAntiGateTest.ImageList

  @moduletag :real_tests

  setup_all do
    Application.put_env(:ex_anti_gate, :language_pool, "rn")
    Application.put_env(:ex_anti_gate, :min_length, 5)
    Application.put_env(:ex_anti_gate, :max_length, 5)
    Application.put_env(:ex_anti_gate, :max_timeout, 30_000)

    :ok
  end

  test "image 0 with push" do

    image = ImageList.get_image(0).image
    code = ImageList.get_image(0).code

    task_uuid = ExAntiGate.solve_text_task(image, push: true)

    assert_receive {:ex_anti_gate_result, {:ready, ^task_uuid, %{text: ^code}}},
                   Application.get_env(:ex_anti_gate, :max_timeout) + 100
  end

  test "image 1 with push" do

    image = ImageList.get_image(1).image
    code = ImageList.get_image(1).code

    task_uuid = ExAntiGate.solve_text_task(image, push: true)

    assert_receive {:ex_anti_gate_result, {:ready, ^task_uuid, %{text: ^code}}},
                   Application.get_env(:ex_anti_gate, :max_timeout) + 100
  end

  test "image 2 without push" do

    image = ImageList.get_image(2).image
    code = ImageList.get_image(2).code

    task_uuid = ExAntiGate.solve_text_task(image)

    :timer.sleep 25_000

    task = ExAntiGate.get_task(task_uuid)

    assert task.status == :ready
    assert task.result.text == code
  end

end
