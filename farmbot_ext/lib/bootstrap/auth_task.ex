defmodule Farmbot.Bootstrap.AuthTask do
  @moduledoc "Background worker that refreshes a token every 30 minutes."
  use GenServer
  require Farmbot.Logger
  alias Farmbot.Config
  import Config, only: [update_config_value: 4, get_config_value: 3]

  # 30 minutes.
  @refresh_time 1.8e+6 |> round()
  # @refresh_time 5_000

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  @doc "Force the token to refresh. Restarts any transports?"
  def force_refresh do
    GenServer.call(__MODULE__, :force_refresh)
  end

  def init([]) do
    timer = Process.send_after(self(), :refresh, @refresh_time)
    {:ok, timer, :hibernate}
  end

  def terminate(reason, _state) do
    unless reason == {:shutdown, :normal} do
      Farmbot.Logger.error 1, "Token Refresh failed: #{inspect reason}"
    end
  end

  defp do_refresh do
    auth_task = Application.get_env(:farmbot_ext, :behaviour)[:authorization]
    {email, pass, server} = {fetch_email(), fetch_pass(), fetch_server()}
    Farmbot.Logger.busy(3, "refreshing token: #{email} - #{server}")
    case auth_task.authorize(email, pass, server) do
      {:ok, token} ->
        Farmbot.Logger.success(3, "Successful authorization: #{email} - #{server}")
        update_config_value(:bool, "settings", "first_boot", false)
        update_config_value(:string, "authorization", "token", token)
        restart_transports()
        refresh_timer(self())
      {:error, err} ->
        msg = "Token failed to reauthorize: #{email} - #{server} #{inspect err}"
        Farmbot.Logger.error(1, msg)
        # If refresh failed, try again more often
        refresh_timer(self(), 15_000)
    end
  end

  def handle_info(:refresh, _old_timer) do
    do_refresh()
  end

  def handle_call(:force_refresh, _, old_timer) do
    Farmbot.Logger.info 1, "Forcing a token refresh."
    if Process.read_timer(old_timer) do
      Process.cancel_timer(old_timer)
    end
    send self(), :refresh
    {:reply, :ok, nil}
  end

  defp restart_transports do
    bootstrap_sup = Farmbot.Bootstrap.Supervisor
    transport_sup = Farmbot.AMQP.Supervisor
    :ok = Supervisor.terminate_child(bootstrap_sup, transport_sup)
    {:ok, _} = Supervisor.restart_child(bootstrap_sup, transport_sup)
  end

  defp refresh_timer(pid, ms \\ @refresh_time) do
    timer = Process.send_after(pid, :refresh, ms)
    {:noreply, timer, :hibernate}
  end

  defp fetch_email do
    email = get_config_value(:string, "authorization", "email")
    email || raise "No email provided for token refresh."
  end

  defp fetch_pass do
    pass = get_config_value(:string, "authorization", "password")
    pass || raise "No password provided for token refresh."
  end

  defp fetch_server do
    server = get_config_value(:string, "authorization", "server")
    server || raise "No server provided for token refresh."
  end
end
