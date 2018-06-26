defmodule Farmbot.Host.SystemTasks do
  @moduledoc "Host implementation for Farmbot.System."

  @behaviour Farmbot.System

  def reboot() do
    Application.stop(:farmbot_os)
    Application.ensure_all_started(:farmbot_os)
  end

  def shutdown() do
    :init.stop()
  end

  def stop(_), do: :ok
end
