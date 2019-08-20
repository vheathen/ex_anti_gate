defmodule ExAntiGate.Tasks.FunCaptchaTaskProxyless do
  @moduledoc false

  def defaults, do:
   [
      type: "FunCaptchaTaskProxyless",
      websiteURL: nil,
      funcaptchaApiJSSubdomain: nil,
      websitePublicKey: nil
    ]
end
