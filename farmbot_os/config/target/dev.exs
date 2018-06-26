use Mix.Config
local_file = Path.join(System.user_home!(), ".ssh/id_rsa.pub")
local_key = if File.exists?(local_file), do: [File.read!(local_file)], else: []

config :logger, [
  utc_log: true,
  # handle_otp_reports: true,
  # handle_sasl_reports: true,
  backends: [RingLogger]
]

config :nerves_firmware_ssh,
  authorized_keys: local_key,
  ssh_console_port: 22

data_path = Path.join("/", "root")
config :farmbot_ext,
  data_path: data_path

config :farmbot_core, Farmbot.Config.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: Path.join(data_path, "config-#{Mix.env()}.sqlite3"),
  pool_size: 1

config :farmbot_core, Farmbot.Logger.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: Path.join(data_path, "logs-#{Mix.env()}.sqlite3"),
  pool_size: 1

config :farmbot_core, Farmbot.Asset.Repo,
  adapter: Sqlite.Ecto2,
  loggers: [],
  database: Path.join(data_path, "repo-#{Mix.env()}.sqlite3"),
  pool_size: 1

config :farmbot_os,
  ecto_repos: [Farmbot.Config.Repo, Farmbot.Logger.Repo, Farmbot.Asset.Repo],
  platform_children: []

config :farmbot_os, :behaviour,
  update_handler: Farmbot.Target.UpdateHandler,
  system_tasks: Farmbot.Target.SystemTasks
