defmodule Farmbot.CeleryScript.Scheduler do
  @moduledoc """
  Behaviour for the celeryscript scheduler.
  """

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end


  @scheduler Application.get_env(:farmbot_core, :behaviour)[:celery_scheduler]
  @scheduler || Mix.raise("No celery_scheduler")

  @doc false
  @callback start_link([]) :: GenServer.on_start()

  @doc "Schedule and wait for some celeryscript to complete."
  @callback schedule(Farmbot.CeleryScript.AST.t) :: any

  @doc "Schedule some celeryscript to complete. Can be awaited on in the future."
  @callback schedule_async(Farmbot.CeleryScript.AST.t) :: reference

  @doc "Get the results of the async sceduled celeryscript."
  @callback await(reference) :: any

  @doc false
  def start_link(args), do: @scheduler.start_link(args)

  @doc "Schedule and wait for some celeryscript to complete."
  def schedule(ast), do: @scheduler.schedule(ast)

  @doc "Schedule some celeryscript to complete. Can be awaited on in the future."
  def schedule_async(ast), do: @scheduler.schedule_async(ast)

  @doc "Get the results of the async sceduled celeryscript."
  def await(reference), do: @scheduler.await(reference)
end
