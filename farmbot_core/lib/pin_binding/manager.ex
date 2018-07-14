defmodule Farmbot.PinBinding.Manager do
  @moduledoc "Handles PinBinding inputs and outputs"
  use GenServer
  require Farmbot.Logger
  alias __MODULE__, as: State
  alias Farmbot.Asset
  alias Asset.{PinBinding, Sequence}
  @handler Application.get_env(:farmbot_core, :behaviour)[:pin_binding_handler]
  @handler || Mix.raise("No pin binding handler.")

  defstruct [registered: %{}, handler: nil]

  # Should be called by a handler
  @doc false
  def trigger(pin) do
    GenServer.cast(__MODULE__, {:pin_trigger, pin})
  end

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([]) do
    case @handler.start_link() do
      {:ok, handler} ->
        Farmbot.Registry.subscribe(self())
        all = Asset.all_pin_bindings()
        state = initial_state(all, struct(State, handler: handler))
        {:ok, state}
      err -> err
    end
  end

  def terminate(reason, state) do
    if state.handler do
      if Process.alive?(state.handler) do
        GenServer.stop(state.handler, reason)
      end
    end
  end

  defp initial_state([], state), do: state

  defp initial_state([%PinBinding{pin_num: pin} = binding | rest], state) do
    case @handler.register_pin(pin) do
      :ok ->
        new_state = do_register(state, binding)
        initial_state(rest, new_state)
      _ ->
        initial_state(rest, state)
    end
  end

  def handle_cast({:pin_trigger, pin}, state) do
    case state.registered[pin] do
      %PinBinding{} = binding ->
        Farmbot.Logger.busy(1, "PinBinding #{pin} triggered")
        do_execute(binding)
      nil ->
        Farmbot.Logger.warn(3, "No sequence assosiated with: #{pin}")
    end
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, {Asset, {:addition, %PinBinding{} = binding}}}, state) do
    state = register_pin(state, binding)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, {Asset, {:deletion, %PinBinding{} = binding}}}, state) do
    state = unregister_pin(state, binding)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, {Asset, {:update, %PinBinding{} = binding}}}, state) do
    state = state
    |> unregister_pin(binding)
    |> register_pin(binding)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, _}, state) do
    {:noreply, state}
  end

  defp register_pin(state, %PinBinding{pin_num: pin_num} = binding) do
    Farmbot.Logger.info 1, "Registering #{pin_num} to sequence by id"
    case state.registered[pin_num] do
      nil ->
        case @handler.register_pin(pin_num) do
          :ok -> do_register(state, binding)

          {:error, reason} ->
            Farmbot.Logger.error(1, "Error registering pin: #{inspect reason}")
            state
        end

      _ ->
        Farmbot.Logger.error(1, "Error registering pin: pin already registered")
        state
    end
  end

  def unregister_pin(state, %PinBinding{pin_num: pin_num}) do
    case state.registered[pin_num] do
      nil ->
        Farmbot.Logger.error(1, "Error unregistering pin: pin not unregistered")
        state

      %PinBinding{} = old ->
        Farmbot.Logger.info 1, "Unregistering #{pin_num} from sequence by id"
        case @handler.unregister_pin(pin_num) do
          :ok ->
            do_unregister(state, old)

          {:error, reason} ->
            Farmbot.Logger.error 1, "Error unregistering pin: #{inspect reason}"
            state
        end
    end
  end

  defp do_register(state, %PinBinding{pin_num: pin} = binding) do
    %{state | registered: Map.put(state.registered, pin, binding)}
  end

  defp do_unregister(state, %PinBinding{pin_num: pin_num}) do
    %{state | registered: Map.delete(state.registered, pin_num)}
  end

  defp do_execute(%PinBinding{sequence_id: sequence_id}) when is_number(sequence_id) do
    sequence_id
    |> Farmbot.Asset.get_sequence_by_id!()
    |> Farmbot.CeleryScript.schedule_sequence()
  end

  defp do_execute(%PinBinding{special_action: action}) when is_binary(action) do
    %Sequence{
      id: 0,
      name: action,
      kind: action,
      args: %{},
      body: [] }
    |> Farmbot.CeleryScript.schedule_sequence()
  end
end
