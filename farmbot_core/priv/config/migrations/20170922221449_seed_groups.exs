defmodule Farmbot.Config.Repo.Migrations.SeedGroups do
  use Ecto.Migration
  alias Farmbot.Config.{Repo, Group, StringValue, BoolValue, FloatValue}
  import Farmbot.Config.MigrationHelpers
  import Ecto.Query, only: [from: 2]

  @group_names ["authorization", "hardware_params", "settings"]
  @default_server Application.get_env(:farmbot_core, :default_server)
  @default_server || raise("Missing application env config: `:default_server`")

  def change do
    populate_config_groups()
    populate_config_values()
  end

  defp populate_config_groups do
    for name <- @group_names do
      %Group{group_name: name}
      |> Group.changeset()
      |> Repo.insert()
    end
  end

  defp populate_config_values do
    for name <- @group_names do
      [group_id] =
        from(g in Group, where: g.group_name == ^name, select: g.id) |> Repo.all()

      populate_config_values(name, group_id)
    end
  end

  defp populate_config_values("authorization", group_id) do
    create_value(StringValue, @default_server) |> create_config(group_id, "server")
    create_value(StringValue, nil) |> create_config(group_id, "email")
    create_value(StringValue, nil) |> create_config(group_id, "password")
    create_value(StringValue, nil) |> create_config(group_id, "token")
  end

  defp populate_config_values("settings", group_id) do
    create_value(BoolValue, true)   |> create_config(group_id, "os_auto_update")
    create_value(BoolValue, true)   |> create_config(group_id, "ignore_external_logs")
    create_value(BoolValue, true)   |> create_config(group_id, "first_boot")
    create_value(BoolValue, true)   |> create_config(group_id, "first_sync")
    create_value(StringValue, "A")  |> create_config(group_id, "current_repo")
    create_value(BoolValue, true)   |> create_config(group_id, "first_party_farmware")
    create_value(BoolValue, false)  |> create_config(group_id, "auto_sync")
    create_value(StringValue, nil)  |> create_config(group_id, "firmware_hardware")
    create_value(StringValue, nil)  |> create_config(group_id, "timezone")
    create_value(StringValue, "{}") |> create_config(group_id, "user_env")
    fpf_url = Application.get_env(:farmbot_core, :farmware)[:first_part_farmware_manifest_url]
    create_value(StringValue, fpf_url) |> create_config(group_id, "first_party_farmware_url")
  end

  defp populate_config_values("hardware_params", group_id) do
    create_value(FloatValue, nil) |> create_config(group_id, "param_version")
    create_value(FloatValue, nil) |> create_config(group_id, "param_test")
    create_value(FloatValue, nil) |> create_config(group_id, "param_config_ok")
    create_value(FloatValue, nil) |> create_config(group_id, "param_use_eeprom")
    create_value(FloatValue, nil) |> create_config(group_id, "param_e_stop_on_mov_err")
    create_value(FloatValue, nil) |> create_config(group_id, "param_mov_nr_retry")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_timeout_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_timeout_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_timeout_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_keep_active_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_keep_active_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_keep_active_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_at_boot_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_at_boot_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_at_boot_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_endpoints_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_endpoints_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_endpoints_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_enable_endpoints_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_enable_endpoints_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_enable_endpoints_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_motor_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_motor_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_invert_motor_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_secondary_motor_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_secondary_motor_invert_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_steps_acc_dec_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_steps_acc_dec_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_steps_acc_dec_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_home_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_home_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_home_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_up_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_up_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_up_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_step_per_mm_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_step_per_mm_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_step_per_mm_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_min_spd_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_min_spd_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_min_spd_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_spd_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_spd_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_home_spd_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_max_spd_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_max_spd_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_max_spd_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_enabled_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_enabled_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_enabled_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_type_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_type_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_type_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_max_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_max_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_max_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_scaling_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_scaling_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_scaling_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_decay_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_decay_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_missed_steps_decay_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_use_for_pos_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_use_for_pos_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_use_for_pos_z")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_invert_x")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_invert_y")
    create_value(FloatValue, nil) |> create_config(group_id, "encoder_invert_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_axis_nr_steps_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_axis_nr_steps_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_axis_nr_steps_z")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_max_x")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_max_y")
    create_value(FloatValue, nil) |> create_config(group_id, "movement_stop_at_max_z")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_1_pin_nr")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_1_time_out")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_1_active_state")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_2_pin_nr")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_2_time_out")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_2_active_state")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_3_pin_nr")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_3_time_out")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_3_active_state")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_4_pin_nr")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_4_time_out")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_4_active_state")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_5_pin_nr")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_5_time_out")
    create_value(FloatValue, nil) |> create_config(group_id, "pin_guard_5_active_state")
  end
end
