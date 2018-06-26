defmodule Farmbot.CeleryScript.StubScheduler do
  @moduledoc "Stub scheduler implementation."

  use GenServer
  @behaviour Farmbot.CeleryScript.Scheduler

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def schedule(_ast) do
    :ok
  end

  def schedule_async(_ast) do
    make_ref()
  end

  def await(_ref) do
    :ok
  end
end
