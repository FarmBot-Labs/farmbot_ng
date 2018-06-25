defmodule Farmbot.Asset.Regimen do
  @moduledoc """
  A Regimen is a schedule to run sequences on.
  """

  alias Farmbot.EctoTypes.TermType
  alias Farmbot.Regimen.NameProvider
  alias Farmbot.Regimen.Supervisor, as: RegimenSupervisor

  use Ecto.Schema
  import Ecto.Changeset

  schema "regimens" do
    field(:name, :string)
    field(:farm_event_id, :integer, virtual: true)
    field(:regimen_items, TermType)
  end

  @type item :: %{
          name: String.t(),
          time_offset: integer,
          sequence_id: integer
        }

  @type t :: %__MODULE__{
          name: String.t(),
          regimen_items: [item]
        }

  @required_fields [:id, :name, :regimen_items]

  def changeset(farm_event, params \\ %{}) do
    farm_event
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:id)
  end

  @behaviour Farmbot.Asset.FarmEvent
  def schedule_event(regimen, now) do
    name = NameProvider.via(regimen)
    case GenServer.whereis(name) do
      nil -> {:ok, _pid} = RegimenSupervisor.add_child(regimen, now)
      pid -> {:ok, pid}
    end
  end
end
