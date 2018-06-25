defmodule Farmbot.Config.MigrationHelpers do
  @moduledoc false

  # This is pretty bad practice, but i don't plan on really changing it at all.

  alias Farmbot.Config
  alias Config.{Repo, Config, StringValue, BoolValue, FloatValue}

  @auth_group_id 1
  @hw_param_group_id 2
  @settings_group_id 3

  def create_auth_config(key, type, value) when type in [:string, :float, :bool] do
    create_value(type_to_mod(type), value)
    |> create_config(@auth_group_id, key)
  end

  def create_settings_config(key, type, value) when type in [:string, :float, :bool] do
    create_value(type_to_mod(type), value)
    |> create_config(@settings_group_id, key)
  end

  def create_hw_param(key) when is_binary(key) do
    create_value(FloatValue, nil) |> create_config(@hw_param_group_id, key)
  end

  defp type_to_mod(:string), do: StringValue
  defp type_to_mod(:float), do: FloatValue
  defp type_to_mod(:bool), do: BoolValue

  def create_config(value, group_id, key) do
    %Config{group_id: group_id, key: key}
    |> Map.put(
         :"#{Module.split(value.__struct__) |> List.last() |> Macro.underscore()}_id",
         value.id
       )
    |> Config.changeset()
    |> Repo.insert!()
  end

  def create_value(type, val \\ nil) do
    unless Code.ensure_loaded?(type) do
      raise "Unknown type: #{type}"
    end

    type
    |> struct()
    |> Map.put(:value, val)
    |> type.changeset()
    |> Repo.insert!()
  end
end
