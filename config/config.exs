# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :ex_anti_gate, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:ex_anti_gate, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

config :ex_anti_gate,
    autostart: true, # Start ExAntiGate process on application start

    # ############################# task options #####################################

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

if Mix.env == :dev do
  config :mix_test_watch,
    tasks: [
      "test",
      "dogma",
    ]
end

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
