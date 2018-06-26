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
    firmware_version: nil,
    sync_status: nil,
    locked: nil,
    last_status: nil,
    cache_bust: nil,
    busy: nil
  ]
end
