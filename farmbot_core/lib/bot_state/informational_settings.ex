defmodule Farmbot.BotState.InformationalSettings do
  @moduledoc false
  import Farmbot.Project
  defstruct [
    target: target(),
    env: env(),
    node_name: node(),
    controller_version: version(),
    firmware_commit: arduino_commit(),
    commit: commit(),
    soc_temp: nil,
    wifi_level: nil,
    firmware_version: nil,
    sync_status: :sync_now,
    last_status: :sync_now,
    locked: nil,
    cache_bust: nil,
    busy: nil
  ]
end
