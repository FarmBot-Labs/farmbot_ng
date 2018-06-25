defmodule Farmbot.Config.Repo.Migrations.AddEAVTables do
  use Ecto.Migration

  def change do
    create table("groups") do
      add(:group_name, :string)
    end

    create table("string_values") do
      add(:value, :string)
    end

    create table("bool_values") do
      add(:value, :boolean)
    end

    create table("float_values") do
      add(:value, :float)
    end

    create table("configs") do
      add(:group_id, references(:groups), null: false)
      add(:string_value_id, references(:string_values))
      add(:bool_value_id, references(:bool_values))
      add(:float_value_id, references(:float_values))
      add(:key, :string)
    end

    create table("network_interfaces") do
      add(:name, :string, null: false)
      add(:type, :string, null: false)

      add(:ssid, :string)
      add(:psk, :string)
      add(:security, :string)

      add(:ipv4_method, :string)
    end
  end
end
