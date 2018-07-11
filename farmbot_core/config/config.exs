use Mix.Config

# config :logger, [
#   utc_log: true,
#   handle_otp_reports: true,
#   handle_sasl_reports: true,
# ]

# Configure Farmbot Behaviours.
config :farmbot_core, :behaviour,
  firmware_handler: Farmbot.Firmware.StubHandler,
  leds_handler: Farmbot.Leds.StubHandler,
  pin_binding_handler: Farmbot.PinBinding.StubHandler,
  celery_script_io_layer: Farmbot.CeleryScript.StubIOLayer

config :farmbot_core,
  ecto_repos: [Farmbot.Config.Repo, Farmbot.Logger.Repo, Farmbot.Asset.Repo],
  expected_fw_versions: ["6.4.0.F", "6.4.0.R", "6.4.0.G"],
  default_server: "https://my.farm.bot",
  default_currently_on_beta: String.contains?(to_string(:os.cmd('git rev-parse --abbrev-ref HEAD')), "beta"),
  firmware_io_logs: false,
  farm_event_debug_log: false

config :farmbot_core, Farmbot.Config.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: ".#{Mix.env}_configs.sqlite3",
  priv: "priv/config",
  pool_size: 1

config :farmbot_core, Farmbot.Logger.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: ".#{Mix.env}_logs.sqlite3",
  priv: "priv/logger",
  pool_size: 1

config :farmbot_core, Farmbot.Asset.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: ".#{Mix.env}_assets.sqlite3",
  priv: "priv/asset",
  pool_size: 1
