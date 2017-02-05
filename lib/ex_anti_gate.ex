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
          result_retry_inteval: 5_000,     # delay between captcha status checks, in milliseconds
          retry_on_error_interval: 5_000,  # delay between retries to catch free slot to proceed captcha, in milliseconds
          max_retries_on_error: 0,         # number of retries to catch a free slot,
                                           # 0 - until (max_timeout - result_request_inteval) milliseconds gone
          max_timeout: 120_000,            # captcha recognition maximum timeout
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
                    created_at: nil,
                    updated_at: nil,
                    type: nil,
                    image: nil,
                    status: :waiting,
                    result: :none
                  }

  use GenServer
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
  def set_result(task_uuid, result) do
    GenServer.cast(__MODULE__, {:set_result, task_uuid, result})
  end

  # #########################################################
  # Server API
  # #########################################################

  @doc false
  def handle_call({:get_task, task_uuid}, _from, state) do
    {:reply, Map.get(state, task_uuid), state}
  end

  # generate task uuid, put image data into state, send solving to itself
  # and return task uuid
  @doc false
  def handle_call({:solve_text, image, options}, from, state) do
    task_uuid = generate()

    task = options
           |> merge_options()
           |> Map.merge(%{from: from, image: image, type: "ImageToTextTask"})

    GenServer.cast(__MODULE__, {:proceed_text_task, task_uuid})

    {:reply, task_uuid, Map.merge(state, %{task_uuid => task})}
  end

  # Get image from state, send request to antigate and
  @doc false
  def handle_cast({:proceed_text_task, task_uuid}, state) do

    task = state[task_uuid]

    :timer.sleep(task.max_timeout)
    # TODO: actual image solving

    state =
      if state[task_uuid].push do
        {from_pid, _} = task.from
        GenServer.cast(from_pid, {:antigate_result, task_uuid})
        state |> Map.delete(task_uuid)
      else
        state
      end

    {:noreply, state}
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
       minLength: full_task.minLength,
       maxLength: full_task.maxLength,
    }
  end

  defp merge_options(options) do
    now = now()

    :ex_anti_gate
    |> Application.get_all_env()
    |> Enum.concat(options)
    |> Enum.into(%{})
    |> Map.delete(:included_applications)
    |> Map.merge(@task_defaults)
    |> Map.put(:created_at, now)
    |> Map.put(:updated_at, now)
  end

  defp now(timeunit \\ :millisecond) do
    DateTime.utc_now()
    |> DateTime.to_unix(timeunit)
  end
end
