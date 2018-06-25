defmodule Farmbot.Asset.SyncCmd do
  @moduledoc "describes an update to a API resource."

  use Ecto.Schema
  import Ecto.Changeset
  alias Farmbot.EctoTypes.TermType

  schema "sync_cmds" do
    field(:remote_id, :integer)
    field(:kind, :string)
    field(:body, TermType)
    timestamps()
  end

  @required_fields [:remote_id, :kind]

  def changeset(%__MODULE__{} = cmd, params \\ %{}) do
    cmd
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end
