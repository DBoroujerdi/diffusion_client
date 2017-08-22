use Mix.Config

config :logger, handle_sasl_reports: true

import_config "#{Mix.env}.exs"
