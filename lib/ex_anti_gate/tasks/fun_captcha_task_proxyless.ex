defmodule ExAntiGate.Tasks.FunCaptchaTaskProxyless do
  @moduledoc false

  def defaults, do:
   [
      type: "FunCaptchaTaskProxyless",
      websiteURL: nil,
      funcaptchaApiJSSubdomain: nil,
      websitePublicKey: nil
    ]

  def config_key, do: :fun_captcha_proxyless

end
