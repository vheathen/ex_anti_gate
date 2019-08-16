defmodule ExAntiGate.Config do
  @moduledoc false

  def get_defaults do
    %{
        autostart: true, # Start ExAntiGate process on application start
        http_client: HTTPoison, # http client - change for testing proposes only

        # ############################# task options #####################################

        api_key: nil,
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
  end

  def get_all_env do
    get_defaults()
    |> Enum.map(fn({k, _}) -> {k, get(k)} end)
  end

  @doc """
  Fetches a value from the config, or from the environment if {:system, "VAR"}
  is provided.
  An optional default value can be provided if desired.
  ## Example
      iex> {test_var, expected_value} = System.get_env |> Enum.take(1) |> List.first
      ...> Application.put_env(:myapp, :test_var, {:system, test_var})
      ...> ^expected_value = #{__MODULE__}.get(:myapp, :test_var)
      ...> :ok
      :ok
      iex> Application.put_env(:myapp, :test_var2, 1)
      ...> 1 = #{__MODULE__}.get(:myapp, :test_var2)
      1
      iex> :default = #{__MODULE__}.get(:myapp, :missing_var, :default)
      :default
  """
  @spec get(atom, atom, term | nil) :: term
  def get(app, key, default \\ nil) when is_atom(app) and is_atom(key) do
    case Application.get_env(app, key) do
      {:system, env_var} ->
        case System.get_env(env_var) do
          nil -> default
          val -> val
        end
      {:system, env_var, preconfigured_default} ->
        case System.get_env(env_var) do
          nil -> preconfigured_default
          val -> val
        end
      nil ->
        if is_nil(default), do: Map.get(get_defaults(), key)
      val ->
        val
    end
  end

  def get(key) when is_atom(key) do
    get(:ex_anti_gate, key)
  end

  @doc """
  Same as get/3, but returns the result as an integer.
  If the value cannot be converted to an integer, the
  default is returned instead.
  """
  @spec get_integer(atom(), atom(), integer() | nil) :: integer() | nil
  def get_integer(app, key, default \\ nil) do
    case get(app, key, nil) do
      nil -> default
      n when is_integer(n) -> n
      n ->
        case Integer.parse(n) do
          {i, _} -> i
          :error -> default
        end
    end
  end

  def get_integer(key) do
    get_integer(:ex_anti_gate, key)
  end
end
