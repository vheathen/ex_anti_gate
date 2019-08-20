defmodule ExAntiGate.Tasks.NoCaptchaTaskProxyless do
  @moduledoc false

  def defaults, do:
   [
      type: "NoCaptchaTaskProxyless",
      websiteURL: nil,
      websiteKey: nil,
      websiteSToken: nil,
      isInvisible: nil
    ]
end
