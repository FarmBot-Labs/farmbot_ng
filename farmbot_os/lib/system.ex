defmodule Farmbot.System do
  @moduledoc """
  Common functionality that should be implemented by a system
  """

  error_msg = """
  Please configure `:system_tasks` and `:data_path`!
  """

  @system_tasks Application.get_env(:farmbot_os, :behaviour)[:system_tasks]
  @system_tasks || Mix.raise(error_msg)

  @data_path Application.get_env(:farmbot_ext, :data_path)
  @data_path || Mix.raise(error_msg)

  @doc "Restarts the machine."
  @callback reboot() :: any

  @doc "Shuts down the machine."
  @callback shutdown() :: any

  @doc "Reads the last shutdown is there was one."
  def last_shutdown_reason do
    file = Path.join(@data_path, "last_shutdown_reason")
    case File.read(file) do
      {:ok, data} -> data
      _ -> nil
    end
  end

  @doc "Remove all configuration data, and reboot."
  @spec factory_reset(any) :: no_return
  def factory_reset(reason) do
    alias Farmbot.Config
    import Config, only: [get_config_value: 3]
    if Process.whereis Farmbot.Core do
      if get_config_value(:bool, "settings", "disable_factory_reset") do
        reboot(reason)
      else
        do_reset(reason)
      end
    else
      do_reset(reason)
    end
  end

  defp do_reset(reason) do
    Application.stop(:farmbot_ext)
    Application.stop(:farmbot_core)
    for p <- Path.wildcard(Path.join(@data_path, "*")) do
      File.rm_rf!(p)
    end
    reboot(reason)
  end

  @doc "Reboot."
  @spec reboot(any) :: no_return
  def reboot(reason) do
    write_file(reason)
    @system_tasks.reboot()
  end

  @doc "Shutdown."
  @spec shutdown(any) :: no_return
  def shutdown(reason) do
    write_file(reason)
    @system_tasks.shutdown()
  end

  defp write_file(nil) do
    file = Path.join(@data_path, "last_shutdown_reason")
    File.rm_rf(file)
  end

  defp write_file(reason) do
    file = Path.join(@data_path, "last_shutdown_reason")
    File.write!(file, inspect(reason))
  end
end
