defmodule Farmbot.Host.Configurator do
  @moduledoc false
  use Supervisor
  
  import Farmbot.Config,
    only: [update_config_value: 4, get_config_value: 3]

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  defp start_node() do
    case Node.start(:"farmbot-host@127.0.0.1") do
      {:ok, _} -> :ok
      _ -> :ok
    end
  end

  def init(_) do
    start_node()
    # Get out authorization data out of the environment.
    # for host environment this will be configured at compile time.
    # for target environment it will be configured by `configurator`.
    email = Application.get_env(:farmbot_os, :authorization)[:email] || raise error("email")
    pass = Application.get_env(:farmbot_os, :authorization)[:password] || raise error("password")
    server = Application.get_env(:farmbot_os, :authorization)[:server] || raise error("server")
    update_config_value(:string, "authorization", "email", email)

    # if there is no firmware hardware, default ot farmduino
    unless get_config_value(:string, "settings", "firmware_hardware") do
      update_config_value(:string, "settings", "firmware_hardware", "farmduino")
    end

    if get_config_value(:bool, "settings", "first_boot") do
      update_config_value(:string, "authorization", "password", pass)
    end
    update_config_value(:string, "authorization", "server", server)
    update_config_value(:string, "authorization", "token", nil)
    :ignore
  end

  defp error(_field) do
    """
    Your environment is not properly configured! You will need to follow the
    directions in `config/host/auth_secret_template.exs` before continuing.
    """
  end
end
