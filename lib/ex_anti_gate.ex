defmodule ExAntiGate do
  @moduledoc """
  This is documentation for ExAntiGate.

  ## Disclimer
  This project has been intended for fair use only. It's not allowed to use it for any destructive,
  anti-social and/or illegal activity.

  ## Description
  Unofficial client for [anti-captcha.com](http://anti-captcha.com) ([antigate.com](http://antigate.com)) API.
  The antigate service solves captchas by human workers.

  ## Configuration
  The Antigate client has to be configured. At least `api_key` has to be set, otherwise the client
  is shutting down with a notice.

  Default options look like this:

      config :ex_anti_gate,
          autostart: true, # Start ExAntiGate process on application start

          ################################# task options #####################################

          api_key: nil,
          api_host: "https://api.anti-captcha.com",
          language_pool: "en",             # "en" (default) - english queue,
                                           # "rn" - Russian, Ukrainian, Belorussian, Kazakh language group
          result_request_interval: 10_000, # result request first attemt interval, in milliseconds
          result_retry_inteval: 2_000,     # delay between captcha status checks, in milliseconds
          no_slot_retry_interval: 5_000,   # delay between retries to catch a free slot to proceed captcha, in milliseconds
          no_slot_max_retries: 0,          # number of retries to catch a free slot,
                                           # 0 - until (max_timeout - result_request_inteval) milliseconds gone
          max_timeout: 120_000,            # captcha recognition maximum timeout;
                                           # the result value must be read during this period
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
  """

  @task_defaults %{
                    from: nil,
                    timer: nil,
                    type: nil,
                    image: nil,
                    no_slot_attempts: 0,
                    status: :waiting, # or :ok, or :error
                    result: :none,
                    api_task_id: nil
                  }

  use GenServer
  require Logger
  import Ecto.UUID, only: [generate: 0]

  # #########################################################
  # Client API
  # #########################################################

  @doc """
  Starts the antigate client linked process
  Can be used if `:autostart` config option set to `false`
  """
  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Starts the antigate client process
  Can be used if `:autostart` config option set to `false`
  """
  def start(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Creates a new task for text captcha recognition
  Returns a UUID string as a task id
  """
  @spec solve_text_task(String.t(), List) :: String.t()
  def solve_text_task(image, options \\ []) do
    GenServer.call(__MODULE__, {:solve_text, image, options})
  end

  @doc """
  Returns a task full current state by uuid
  """
  def get_task(task_uuid) do
    GenServer.call(__MODULE__, {:get_task, task_uuid})
  end

  @doc """
  Returns task current status with result as one of the following:
    * `{:waiting, :none}` - waiting for result
    * `{:ok, String.t() | any}` - captcha solved; the second param has result (string only at the moment)
    * `{:error, String.t()}` - an error with description
  """
  def get_task_result(task_uuid) do
    GenServer.call(__MODULE__, {:get_task_result, task_uuid})
  end

  @doc false
  def proceed_result(task_uuid, result) do
    GenServer.cast(__MODULE__, {:proceed_result, task_uuid, result})
  end

  # #########################################################
  # Server API
  # #########################################################

  @doc false
  def handle_call({:get_task, task_uuid}, _from, state) do
    {:reply, Map.get(state, task_uuid), state}
  end

  # generate task uuid, put image data into state, send request to antigate
  # and return task uuid
  @doc false
  def handle_call({:solve_text, image, options}, from, state) do
    task_uuid = generate()
    options = merge_options(options)
    timer = Process.send_after(self(), {:cancel_task, task_uuid}, options.max_timeout)

    task = Map.merge(options, %{from: from, image: image, type: "ImageToTextTask", timer: timer})

    unless Map.get(task, :fake), do:
        spawn fn ->
          result = task.http_client.post("#{task.api_host}/createTask", Poison.encode!(gen_task_request(task)), [{"Content-Type", "application/json"}])
          ExAntiGate.proceed_result(task_uuid, {:api_task_id, result})
        end

#    GenServer.cast(__MODULE__, {:proceed_text_task, task_uuid})

    {:reply, task_uuid, Map.merge(state, %{task_uuid => task})}
  end

  # Get image from state, send request to antigate and
  @doc false
  def handle_cast({:proceed_text_task, _task_uuid}, state) do

#    task = state[task_uuid]

#    :timer.sleep(task.max_timeout)
    # TODO: actual image solving

#    state =
#      if state[task_uuid].push do
#        {from_pid, _} = task.from
#        GenServer.cast(from_pid, {:antigate_result, task_uuid})
#        state |> Map.delete(task_uuid)
#      else
#        state
#      end

    {:noreply, state}
  end

  def handle_cast({:proceed_result, task_uuid, {:api_task_id, result}}, state) do
    state =
      with task when not is_nil(task) <- Map.get(state, task_uuid),
           {:ok, %HTTPoison.Response{ body: body, status_code: 200 }} <- result,
           {:ok, json_body} <- Poison.decode(body),
           %{"errorId" => 0, "taskId" => task_id} <- json_body
      do
        put_in(state, [task_uuid, :api_task_id], task_id)

      else
        error ->
          parse_error(task_uuid, error, state)
      end

    {:noreply, state}
  end

  # handle max timeout
  @doc false
  def handle_info({:cancel_task, task_uuid}, state) do

    state =
      task_uuid
      |> parse_error(%{"errorId" => -2, "errorCode" => "ERROR_API_TIMEOUT", "errorDescription" => "Maximum timeout reached, task interrupted"}, state)
      |> Map.delete(task_uuid)

    {:noreply, state}
  end

  # try to get task
  defp parse_error(task_uuid, error, state) when is_binary task_uuid do
    task = Map.get(state, task_uuid)
    parse_error(task, task_uuid, error, state)
  end

  # if task is nil just return state
  defp parse_error(task, _task_uuid, _error, state) when is_nil task do
    state
  end
  # if error is HTTPoison client error
  defp parse_error(task, task_uuid, {:error, %HTTPoison.Error{id: error_id, reason: error_code}}, state) do
    proceed_error(task, task_uuid, {error_id, error_code, nil}, state)
  end
  # If error is API or timeout error
  defp parse_error(task, task_uuid, %{"errorCode" => error_code, "errorDescription" => error_descr, "errorId" => error_id}, state) do
    proceed_error(task, task_uuid, {error_id, error_code, error_descr}, state)
  end
  # Any other (unknown?) errors
  defp parse_error(task, task_uuid, error, state) do
    proceed_error(task, task_uuid, {-2, "ERROR_UNKNOWN_ERROR", inspect error}, state)
  end

  # if ERROR_NO_SLOT_AVAILABLE
  defp proceed_error(task, task_uuid, {error_id, _error_code, _error_descr}, state) when error_id == 2 do
    # TODO: Retry
    state
  end
  # if we need to push info
  defp proceed_error(%{push: true, from: {to, _}, timer: timer} = _task, task_uuid, {error_id, error_code, error_descr}, state) do
    Process.send(to, {:ex_anti_gate_result, {:error, task_uuid, error_id, error_code, error_descr}}, [])
    Process.cancel_timer(timer)
    Map.delete(state, task_uuid)
  end
  defp proceed_error(_task, task_uuid, {error_id, error_code, error_descr}, state) do
    state
    |> put_in([task_uuid, :result], {error_id, error_code, error_descr})
    |> put_in([task_uuid, :status], :error)
  end

  defp gen_task_request(full_task) do
    %{
        clientKey: full_task.api_key,
        softId: "",
        languagePool: full_task.language_pool,
        task: gen_text_task(full_task)
    }
  end

  defp gen_text_task(full_task) do
    %{
       type: full_task.type,
       body: full_task.image,
       phrase: full_task.phrase,
       case: full_task.case,
       numeric: full_task.numeric,
       math: full_task.math,
       minLength: full_task.min_length,
       maxLength: full_task.max_length,
    }
  end

  defp merge_options(options) do
    :ex_anti_gate
    |> Application.get_all_env()
    |> Enum.concat(options)
    |> Enum.into(%{})
    |> Map.delete(:included_applications)
    |> Map.merge(@task_defaults)
  end

end
