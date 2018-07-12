defmodule Farmbot.System.Watchdog do
  @moduledoc "Watches a process and does things if/when it crashes."
  use GenServer
  require Logger

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([pid, app]) do
    ref = Process.monitor(pid)
    {:ok, %{monitor: ref, pid: pid, app: app}}
  end

  def handle_info({:DOWN, ref, :process, _id, reason}, %{monitor: ref} = state) do
    Logger.error "[#{inspect ref}] Watchdog process caught exit: #{inspect state.pid} #{inspect reason}"
    Application.ensure_all_started(state.app)
    {:noreply, state}
  end
end
