defmodule Farmbot.System.SeedDB do
  use GenServer
  alias Farmbot.Asset
  @builtins Application.get_env(:farmbot_os, :builtins)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    pin_binding(builtin(:pin_binding, :emergency_lock), "emergency_lock", 17)
    pin_binding(builtin(:pin_binding, :emergency_unlock), "emergency_unlock", 23)

    Asset.fragment_sync()
    :ignore
  end

  def pin_binding(id, special_action, pin_num) do
    body = %{id: id, special_action: special_action, pin_num: pin_num}
    Asset.register_sync_cmd(id, "PinBinding", body)
  end

  def builtin(kind, label) do
    @builtins[kind][label] || raise("no #{kind} builtin by label: #{label}")
  end
end
