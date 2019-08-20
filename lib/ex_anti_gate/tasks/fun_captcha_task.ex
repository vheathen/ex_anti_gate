defmodule ExAntiGate.Tasks.FunCaptchaTask do
  @moduledoc false

  def defaults, do:
   [
      type: "FunCaptchaTask",
      websiteURL: nil,
      funcaptchaApiJSSubdomain: nil,
      websitePublicKey: nil,
      proxyType: nil,
      proxyAddress: nil,
      proxyPort: nil,
      proxyLogin: nil,
      proxyPassword: nil,
      userAgent: nil,
      cookies: nil
    ]
end
