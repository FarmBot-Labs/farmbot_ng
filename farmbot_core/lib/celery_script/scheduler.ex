defmodule Farmbot.CeleryScript.Scheduler do
  @moduledoc "WIP replacement for CeleryScript implementation."
  use GenServer
  alias Farmbot.CeleryScript.AST

  def schedule(%AST{} = ast) do
    GenServer.call(__MODULE__, {:schedule, ast})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    {:ok, :no_state}
  end
end
