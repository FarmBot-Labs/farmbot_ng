use Mix.Config

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
  init_children: [
    {Farmbot.Target.Leds.AleHandler, []}
  ],
  platform_children: [
    {Farmbot.Firmware.UartHandler.AutoDetector, []},
    {Farmbot.Target.Bootstrap.Configurator, []},
    {Farmbot.Target.Network, []},
    {Farmbot.Target.Network.WaitForTime, []},
    {Farmbot.Target.Network.TzdataTask, []},
    {Farmbot.Target.SocTempWorker, []},
    {Farmbot.Target.Network.InfoSupervisor, []},
    {Farmbot.Target.Uevent.Supervisor, []},
  ]

config :farmbot_os, :behaviour,
  update_handler: Farmbot.Target.UpdateHandler,
  system_tasks: Farmbot.Target.SystemTasks
