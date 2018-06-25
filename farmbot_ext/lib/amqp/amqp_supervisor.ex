defmodule Farmbot.AMQP.Supervisor do
  @moduledoc false

  use Supervisor
  import Farmbot.Config, only: [get_config_value: 3]

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([]) do
    token = get_config_value(:string, "authorization", "token")
    jwt = %{bot: device, mqtt: mqtt_host, vhost: vhost} = Farmbot.Jwt.decode!(token)
    {:ok, conn} = open_connection(token, device, mqtt_host, vhost)
    children = [
      {Farmbot.AMQP.LogTransport,          [conn, jwt]},
      {Farmbot.AMQP.BotStateTransport,     [conn, jwt]},
      {Farmbot.AMQP.AutoSyncTransport,     [conn, jwt]},
      {Farmbot.AMQP.CeleryScriptTransport, [conn, jwt]}
    ]
    Supervisor.init(children, [strategy: :one_for_one])
  end

  defp open_connection(token, device, mqtt_server, vhost) do
    opts = [
      host: mqtt_server,
      username: device,
      password: token,
      virtual_host: vhost]
    AMQP.Connection.open(opts)
  end
end
