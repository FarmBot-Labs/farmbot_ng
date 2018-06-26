defmodule Farmbot.System.CoreStart do
  @moduledoc false
  use Supervisor

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Application.ensure_all_started(:farmbot_core)
    children = [
      {Farmbot.System.Watchdog, [Farmbot.Core]}
    ]
    Supervisor.init(children, [strategy: :one_for_one])
  end
end
