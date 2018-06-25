defmodule Farmbot.BotState.InformationalSettings do
  @moduledoc false
  import Farmbot.Project
  defstruct [
    target: target(),
    env: env(),
    node_name: node(),
    firmware_commit: arduino_commit(),
    commit: commit(),
    firmware_version: nil,
    sync_status: nil,
    locked: nil,
    last_status: nil,
    controller_version: version(),
    cache_bust: nil,
    busy: nil
  ]
end
