defmodule Farmbot.Registry.Logger do
  @moduledoc false
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Farmbot.Registry.subscribe()
    {:ok, nil}
  end

  def handle_info(info, state) do
    IO.inspect(info, label: "Registry Logger")
    {:noreply, state}
  end
end
