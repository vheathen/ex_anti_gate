defmodule ExAntiGate.Tasks.ImageToTextTask do
  @moduledoc false

  def defaults, do:
   [
      type: "ImageToTextTask",
      body: nil,
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
    ]
end
