defmodule Farmbot.Target.Network.InfoSupervisor do
  use GenServer
  alias Farmbot.Config

  def start_link(_, opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    configs = Config.get_all_network_configs()
    children = Enum.map(configs, fn(config) ->
      {Farmbot.Target.Network.InfoWorker, [config]}
    end)
    Supervisor.init(children, [strategy: :one_for_one])
  end
end
