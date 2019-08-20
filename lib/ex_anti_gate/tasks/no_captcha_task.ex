defmodule ExAntiGate.Tasks.NoCaptchaTask do
  @moduledoc false

  def defaults, do:
   [
      type: "NoCaptchaTask",
      websiteURL: nil,
      websiteKey: nil,
      websiteSToken: nil,
      proxyType: nil,
      proxyAddress: nil,
      proxyPort: nil,
      proxyLogin: nil,
      proxyPassword: nil,
      userAgent: nil,
      cookies: nil,
      isInvisible: nil
    ]
end
