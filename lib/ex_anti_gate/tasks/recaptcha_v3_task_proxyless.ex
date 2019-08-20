defmodule ExAntiGate.Tasks.RecaptchaV3TaskProxyless do
  @moduledoc false

  def defaults, do:
   [
      type: "RecaptchaV3TaskProxyless",
      websiteURL: nil,
      websiteKey: nil,
      minScore: nil,
      pageAction: nil
    ]

  def config_key, do: :no_captcha

end
