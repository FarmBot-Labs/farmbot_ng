defmodule Farmbot.Host.UpdateHandler do
  @moduledoc false

  @behaviour Farmbot.System.UpdateHandler

  # Update Handler callbacks
  def apply_firmware(_file_path) do
    :ok
  end

  def before_update do
    :ok
  end

  def post_update do
    :ok
  end

  def setup(_env) do
    :ok
  end

  def requires_reboot?, do: false
end
