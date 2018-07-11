defmodule Farmbot.System.ExtStart do
  @moduledoc false
  use Supervisor

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Application.ensure_all_started(:farmbot_ext)
    children = [
      {Farmbot.System.Watchdog, [Farmbot.Ext, :farmbot_ext]}
    ]
    Supervisor.init(children, [strategy: :one_for_one])
  end
end
