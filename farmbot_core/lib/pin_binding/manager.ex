defmodule Farmbot.PinBinding.Manager do
  @moduledoc "Handles PinBinding inputs and outputs"
  use GenServer
  require Farmbot.Logger
  alias Farmbot.Asset
  alias Asset.PinBinding
  @handler Application.get_env(:farmbot_core, :behaviour)[:pin_binding_handler]
  @handler || Mix.raise("No pin binding handler.")

  def trigger(pin) do
    GenServer.cast(__MODULE__, {:pin_trigger, pin})
  end

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  defmodule State do
    @moduledoc false
    defstruct repo_up: false,
              registered: %{},
              handler: nil,
              env: struct(Macro.Env, [])
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

  defp initial_state([], state), do: state

  defp initial_state([%PinBinding{pin_num: pin, sequence_id: sequence_id} | rest], state) do
    case @handler.register_pin(pin) do
      :ok ->
        initial_state(rest, %{state | registered: Map.put(state.registered, pin, sequence_id)})

      _ ->
        initial_state(rest, state)
    end
  end

  def handle_cast({:pin_trigger, pin}, state) do
    sequence_id = state.registered[pin]
    env = if sequence_id do
      Farmbot.Logger.busy(1, "Starting Sequence: #{sequence_id} from pin: #{pin}")
      do_execute(sequence_id, state.env)
    else
      Farmbot.Logger.warn(3, "No sequence assosiated with: #{pin}")
      state.env
    end
    {:noreply, %{state | env: env}}
  end

  def handle_info({Farmbot.Registry, {Asset, {:addition, %PinBinding{} = binding}}}, state) do
    state = register_pin(state, binding.pin_num, binding.sequence_id)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, {Asset, {:deletion, %PinBinding{} = binding}}}, state) do
    state = unregister_pin(state, binding.pin_num)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, {Asset, {:update, %PinBinding{} = binding}}}, state) do
    state = state
      |> unregister_pin(binding.pin_num)
      |> register_pin(binding.pin_num, binding.sequence_id)
    {:noreply, state}
  end

  def handle_info({Farmbot.Registry, _}, state) do
    {:noreply, state}
  end

  defp register_pin(state, pin_num, sequence_id) do
    Farmbot.Logger.info 1, "Registering #{pin_num} to sequence by id: #{sequence_id}"
    case state.registered[pin_num] do
      nil ->
        case @handler.register_pin(pin_num) do
          :ok ->
            %{state | registered: Map.put(state.registered, pin_num, sequence_id)}

          {:error, reason} ->
            Farmbot.Logger.error(1, "Error registering pin: #{inspect reason}")
            state
        end

      _ ->
        Farmbot.Logger.error(1, "Error registering pin: pin already registered")
        state
    end
  end

  def unregister_pin(state, pin_num) do
    case state.registered[pin_num] do
      nil ->
        Farmbot.Logger.error(1, "Error unregistering pin: pin not unregistered")
        state

      sequence_id ->
        Farmbot.Logger.info 1, "Unregistering #{pin_num} from sequence by id: #{sequence_id}"
        case @handler.unregister_pin(pin_num) do
          :ok ->
            %{state| registered: Map.delete(state.registered, pin_num)}

          {:error, reason} ->
            Farmbot.Logger.error 1, "Error unregistering pin: #{inspect reason}"
            state
        end
    end
  end

  def terminate(reason, state) do
    if state.handler do
      if Process.alive?(state.handler) do
        GenServer.stop(state.handler, reason)
      end
    end
  end

  defp do_execute(sequence_id, _env) do
    # import Farmbot.CeleryScript.AST.Node.Execute, only: [execute: 3]
    exit("fixme: execute(sequence_id=#{sequence_id})")
    # try do
    #   case execute(%{sequence_id: sequence_id}, [], env) do
    #     {:ok, env} -> env
    #     {:error, _, env} -> env
    #   end
    # rescue
    #   err ->
    #     message = Exception.message(err)
    #     Farmbot.Logger.warn(2, "Failed to execute sequence #{sequence_id} " <> message)
    #     env
    # end
  end
end
