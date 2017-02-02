use Mix.Config
alias Dogma.Rule

config :dogma,

  # Select a set of rules as a base
  rule_set: Dogma.RuleSet.All,

  # Pick paths not to lint
  exclude: [
    ~r(\Aconfig/),
  ],

  # Override an existing rule configuration
  override: [
    %Rule.LineLength{ enabled: false, max_length: 120 },
#    %Rule.HardTabs{ enabled: false },
#    %Rule.ModuleDoc{ enabled: false },
  ]