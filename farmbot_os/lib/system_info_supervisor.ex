defmodule Farmboot.System.Info.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    children = Application.get_env(:farmbot_os, :system_info_children, [])
    Supervisor.init(children, [strategy: :one_for_one])
  end
end
