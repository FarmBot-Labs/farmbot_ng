defmodule Farmbot.OS do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Farmbot.System.Init.FSCheckup, []},
      {Farmbot.System.Init.Ecto, []},
      {Farmbot.System.CoreStart, []},
      {Farmbot.Platform.Supervisor, []},
      {Farmbot.System.UpdateTimer, []},
      {Farmbot.System.ExtStart, []},
    ]
    opts = [strategy: :one_for_one, name: Farmbot.OS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
