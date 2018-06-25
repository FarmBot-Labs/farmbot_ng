defmodule Farmbot.BotState do
  @moduledoc "Central State accumulator."
  alias Farmbot.BotState
  alias BotState.{
    McuParams,
    LocationData,
    Configuration,
    InformationalSettings,
    Pin
  }

  defstruct [
    mcu_params: struct(McuParams),
    location_data: struct(LocationData),
    configuration: struct(Configuration),
    informational_settings: struct(InformationalSettings),
    pins: %{},
    process_info: %{farmwares: %{}},
    gpio_registry: %{},
    user_env: %{jobs: %{}}
  ]

  use GenStage

  @doc "Fetch the current state."
  def fetch do
    GenStage.call(__MODULE__, :fetch)
  end

  @doc false
  def start_link(args) do
    GenStage.start_link(__MODULE__, args, [name: __MODULE__])
  end

  @doc false
  def init([]) do
    Farmbot.Registry.subscribe()
    send(self(), :get_initial_configuration)
    send(self(), :get_initial_mcu_params)
    {:consumer, struct(BotState), [subscribe_to: [Farmbot.Firmware]]}
  end

  @doc false
  def handle_call(:fetch, _from, state) do
    {:reply, state, [], state}
  end

  @doc false
  def handle_info({Farmbot.Registry, {Farmbot.Config, {"settings", key, val}}}, state) do
    event = {:settings, %{String.to_atom(key) => val}}
    new_state = handle_event(event, state)
    Farmbot.Registry.dispatch(__MODULE__, new_state)
    {:noreply, [], new_state}
  end

  def handle_info(:get_initial_configuration, state) do
    full_config = Farmbot.Config.get_config_as_map()
    settings = full_config["settings"]
    new_state = Enum.reduce(settings, state, fn({key, val}, state) ->
      event = {:settings, %{String.to_atom(key) => val}}
      handle_event(event, state)
    end)
    Farmbot.Registry.dispatch(__MODULE__, new_state)
    {:noreply, [], new_state}
  end

  def handle_info(:get_initial_mcu_params, state) do
    full_config = Farmbot.Config.get_config_as_map()
    settings = full_config["hardware_params"]
    new_state = Enum.reduce(settings, state, fn({key, val}, state) ->
      event = {:mcu_params, %{String.to_atom(key) => val}}
      handle_event(event, state)
    end)
    Farmbot.Registry.dispatch(__MODULE__, new_state)
    {:noreply, [], new_state}
  end

  def handle_info({Farmbot.Registry, _}, state), do: {:noreply, [], state}

  @doc false
  def handle_events(events, _from, state) do
    state = Enum.reduce(events, state, &handle_event(&1, &2))
    Farmbot.Registry.dispatch(__MODULE__, state)
    {:noreply, [], state}
  end

  @doc false
  def handle_event({:informational_settings, data}, state) do
    new_data = Map.merge(state.informational_settings, data) |> Map.from_struct()
    new_informational_settings = struct(InformationalSettings, new_data)
    %{state | informational_settings: new_informational_settings}
  end

  def handle_event({:mcu_params, data}, state) do
    new_data = Map.merge(state.mcu_params, data) |> Map.from_struct()
    new_mcu_params = struct(McuParams, new_data)
    %{state | mcu_params: new_mcu_params}
  end

  def handle_event({:location_data, data}, state) do
    new_data = Map.merge(state.location_data, data) |> Map.from_struct()
    new_location_data = struct(LocationData, new_data)
    %{state | location_data: new_location_data}
  end

  def handle_event({:pins, data}, state) do
    new_data = Enum.reduce(data, state.pins, fn({number, pin_state}, pins) ->
      Map.put(pins, number, struct(Pin, pin_state))
    end)
    %{state | pins: new_data}
  end

  def handle_event({:settings, data}, state) do
    new_data = Map.merge(state.configuration, data) |> Map.from_struct()
    new_configuration = struct(Configuration, new_data)
    %{state | configuration: new_configuration}
  end

  def handle_event(event, state) do
    IO.inspect event, label: "unhandled event"
    state
  end
end
