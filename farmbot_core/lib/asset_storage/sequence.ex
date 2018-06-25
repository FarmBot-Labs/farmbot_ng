defmodule Farmbot.Asset.Sequence do
  @moduledoc """
  A Sequence is a list of CeleryScript nodes.
  """

  alias Farmbot.EctoTypes.TermType
  use Ecto.Schema
  import Ecto.Changeset

  schema "sequences" do
    field(:name, :string)
    field(:kind, :string)
    field(:args, TermType)
    field(:body, TermType)
  end

  @required_fields [:id, :name, :kind, :args, :body]

  def changeset(sequence, params \\ %{}) do
    sequence
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:id)
  end

  @behaviour Farmbot.Asset.FarmEvent
  def schedule_event(sequence, _now) do
    with {:ok, ast} <- Farmbot.CeleryScript.AST.decode(sequence) do
      ast_with_label = %{ast | args: Map.put(ast.args, :label, sequence.name)}
      case Farmbot.CeleryScript.Scheduler.schedule(ast_with_label) do
        {:ok, _} -> :ok
        {:error, reason, _} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
