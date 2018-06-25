defmodule Farmbot.System.CoreStart do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Application.ensure_all_started(:farmbot_core)
    :ignore
  end
end
