defmodule Farmbot.System.ExtStart do
  @moduledoc false
  use Supervisor
  require Logger

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    :ok = start_ext_app(Farmbot.BootState.read())
    Supervisor.init([], [strategy: :one_for_one])
  end

  defp start_ext_app(state) do
    case Application.ensure_all_started(:farmbot_ext) do
      {:ok, _} ->
        Farmbot.BootState.write(:UPANDRUNNING)
        :ok
      {:error, {:farmbot_ext, {{:shutdown, {:failed_to_start_child, child, reason}}, _}}} ->
        msg = "Failed to start farmbot_ext while in state: #{inspect state} child: #{child} => #{inspect reason}"
        Logger.error(msg)
        :ok
    end
  end
end
