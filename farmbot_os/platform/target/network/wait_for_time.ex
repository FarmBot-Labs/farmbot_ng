defmodule Farmbot.Target.Network.WaitForTime do
  @moduledoc "Blocks until time is ready."
  require Farmbot.Logger
  use GenServer

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([]) do
    :ok = wait_for_time()
    Farmbot.Logger.success 3, "Time seems to be set: #{:os.system_time(:seconds)}."
    :ignore
  end

  @doc "Blocks until time is ready."
  def wait_for_time do
    case :os.system_time(:seconds) do
      t when t > 1_474_929 ->
        :ok

      _ ->
        Process.sleep(1000)
        wait_for_time()
    end
  end
end
