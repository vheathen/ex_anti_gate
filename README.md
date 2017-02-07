# ExAntiGate

## Disclaimer
This project has been intended for fair use only. It's not allowed to use it for any destructive, 
anti-social and/or illegal activity.

## Description
Unofficial [anti-captcha.com](http://anti-captcha.com)
([antigate.com](http://antigate.com)) API client for Elixir. The antigate service solves 
captchas by human workers.

## Installation
Add it to your dependencies:

```elixir
# mix.exs
def deps do
  [{:ex_anti_gate, "~> 0.3"}]
end
```

end fetch it with `mix deps.get`.

## Configuration
The Antigate client has to be configured. At least `api_key` MUST be set, otherwise the client
is shutting down with a notice. It's possible to set it in config file or via environment variable
`EX_ANTI_GATE_API_KEY`. Note: in case of both (system and config) options exist at the same time 
the environment variable value will be used. 

Default options look like this:

    config :ex_anti_gate,
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

## Using
It is possible to use it in standard and push mode.

In standard mode you send a task request with `ExAntiGate.solve_text_task/2` function and then can
request current result with `ExAntiGate.get_task_result/1` or a full task stack with `ExAntiGate.get_task/1`.
`get_task_result/1` is preferable.

In push mode you should wait for two kind of tuples:
  * `{:ex_anti_gate_result, {:ready, task_uuid :: String.t(), result :: any}}` in case of successfull task or
  * `{:ex_anti_gate_result, {:error, task_uuid :: String.t(), error_id :: integer, error_code :: String.t(), error_description :: String.t()}}` - in
 case of any errors.

For example:

```elixir
    defmodule MyCaptchaDispatcher do
      use GenServer

      # ...

      # Server API

      def handle_info({:ex_anti_gate_result, {:ready, task_uuid, %{text: text} = _result}}, state) do
        # deal with captcha text
      end

      def handle_info({:ex_anti_gate_result, {:error, task_uuid, error_id, error_code, error_description}}, state) do
        # deal with error
      end

    end
```
Please beware that in push mode task data disappear right after message is sent without any kind of delivery check and
in standard mode task data disappear after `max_timeout` amount of time.

## Errors
You can find most errors description in the [Antigate documentation](https://anticaptcha.atlassian.net/wiki/display/API/Errors).
A number of errors came from this client implementation and have negative codes:

`error_id`: -1, `error_code`: "ERROR_UNKNOWN_ERROR",       `error_description`: will be taken from the error source

`error_id`: -2, `error_code`: "ERROR_API_TIMEOUT",         `error_description`: "Maximum timeout reached, task interrupted."

`error_id`: -3, `error_code`: "ERROR_NO_SLOT_MAX_RETRIES", `error_description`: "Maximum attempts to catch free slot reached, task interrupted."
