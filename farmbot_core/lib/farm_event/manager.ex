defmodule Farmbot.FarmEvent.Manager do
  @moduledoc """
  Manages execution of FarmEvents.

  ## Rules for FarmEvent execution.
  * Regimen
    * ignore `end_time`.
    * ignore calendar.
    * if schedule_time is more than 60 seconds passed due, assume it already
      scheduled, and don't schedule it again.
  * Sequence
    * if `schedule_time` is late, check the calendar.
      * for each item in the calendar, check if it's event is more than
        60 seconds in the past. if not, execute it.
    * if there is only one event in the calendar, ignore the `end_time`
  """

  # credo:disable-for-this-file Credo.Check.Refactor.FunctionArity

  use GenServer
  require Farmbot.Logger
  alias Farmbot.Asset
  alias Farmbot.Asset.{FarmEvent, Sequence, Regimen}
  alias Farmbot.Registry

  @checkup_time 1000
  # @checkup_time 15_000

  ## GenServer

  defmodule State do
    @moduledoc false
    defstruct timer: nil, last_time_index: %{}, events: %{}, checkup: nil
  end

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init([]) do
    Farmbot.Registry.subscribe()
    send(self(), :checkup)
    {:ok, struct(State)}
  end

  def terminate(reason, _state) do
    Farmbot.Logger.error(1, "FarmEvent Manager terminated: #{inspect(reason)}")
  end

  def handle_info({Registry, {Asset, {:addition, %FarmEvent{} = data}}}, state) do
    maybe_farm_event_log("Starting monitor on FarmEvent: #{data.id}.")

    Map.put(state.events, data.id, data)
    |> reindex(state)
  end

  def handle_info({Registry, {Asset, {:deletion, %FarmEvent{} = data}}}, state) do
    maybe_farm_event_log("Destroying monitor on FarmEvent: #{data.id}.")

    if String.contains?(data.executable_type, "Regimen") do
      reg = Farmbot.Asset.get_regimen_by_id(data.executable_id, data.id)

      if reg do
        Farmbot.Regimen.Supervisor.stop_child(reg)
      end
    end

    Map.delete(state.events, data.id)
    |> reindex(state)
  end

  def handle_info({Registry, {Asset, {:update, %FarmEvent{} = data}}}, state) do
    maybe_farm_event_log("Reindexing monitor on FarmEvent: #{data.id}.")

    if String.contains?(data.executable_type, "Regimen") do
      reg = Farmbot.Asset.get_regimen_by_id(data.executable_id, data.id)

      if reg do
        Farmbot.Regimen.Supervisor.reindex_all_managers(
          reg,
          Timex.parse!(data.start_time, "{ISO:Extended}")
        )
      end
    end

    Map.put(state.events, data.id, data)
    |> reindex(state)
  end

  def handle_info({Registry, {Asset, {:deletion, %Regimen{} = data}}}, state) do
    Farmbot.Regimen.Supervisor.stop_all_managers(data)
    {:noreply, state}
  end

  def handle_info({Registry, {Asset, {:update, %Regimen{} = data}}}, state) do
    Farmbot.Regimen.Supervisor.reindex_all_managers(data)
    {:noreply, state}
  end

  def handle_info({Registry, {Asset, {:update, %Sequence{} = sequence}}}, state) do
    for reg <- Farmbot.Asset.get_regimens_using_sequence(sequence.id) do
      Farmbot.Regimen.Supervisor.reindex_all_managers(reg)
    end

    {:noreply, state}
  end

  def handle_info({Registry, _}, state) do
    {:noreply, state}
  end

  def handle_info(:checkup, state) do
    checkup = spawn_monitor(__MODULE__, :async_checkup, [self(), state])
    {:noreply, %{state | timer: nil, checkup: checkup}}
  end

  def handle_info({:DOWN, _, :process, _, {:success, new_state}}, _old_state) do
    timer = Process.send_after(self(), :checkup, @checkup_time)
    {:noreply, %{new_state | timer: timer, checkup: nil}}
  end

  def handle_info({:DOWN, _, :process, _, error}, state) do
    Farmbot.Logger.error(1, "Farmevent checkup process died: #{inspect(error)}")
    timer = Process.send_after(self(), :checkup, @checkup_time)
    {:noreply, %{state | timer: timer, checkup: nil}}
  end

  defp reindex(events, state) do
    events =
      Map.new(events, fn {id, event} ->
        {id, FarmEvent.build_calendar(event)}
      end)

    maybe_farm_event_log("Reindexed FarmEvents")

    if match?({_, _}, state.checkup) do
      Process.exit(
        state.checkup |> elem(0),
        {:success, %{state | events: events}}
      )
    end

    if state.timer do
      Process.cancel_timer(state.timer)
      timer = Process.send_after(self(), :checkup, @checkup_time)
      {:noreply, %{state | events: events, timer: timer}}
    else
      {:noreply, %{state | events: events}}
    end
  end

  def async_checkup(_manager, state) do
    now = get_now()
    all_events = Enum.map(state.events, &FarmEvent.build_calendar(elem(&1, 1)))

    # do checkup is the bulk of the work.
    {late_executables, new} = do_checkup(all_events, now, state)

    unless Enum.empty?(late_executables) do
      # Map over the events for logging.
      # Both Sequences and Regimens have a `name` field.
      names = Enum.map(late_executables, &Map.get(elem(&1, 0), :name))
      Farmbot.Logger.debug(3, "Time for events: #{inspect(names)} to be scheduled.")
      schedule_events(late_executables, now)
    end

    exit(
      {:success,
       %{new | events: Map.new(all_events, fn event -> {event.id, event} end)}}
    )
  end

  defp do_checkup(list, time, late_events \\ [], state)

  defp do_checkup([], _now, late_events, state), do: {late_events, state}

  defp do_checkup([farm_event | rest], now, late_exes, state) do
    # new_late will be a executable event (Regimen or Sequence.)
    {new_late_executable, last_time} =
      check_event(farm_event, now, state.last_time_index[farm_event.id])

    # update state.
    new_state = %{
      state
      | last_time_index:
          Map.put(state.last_time_index, farm_event.id, last_time)
    }

    case new_late_executable do
      # if `new_late_executable` is nil, don't accumulate it.
      nil ->
        do_checkup(rest, now, late_exes, new_state)

      # if there is a new event, accumulate it.
      late_executable ->
        do_checkup(
          rest,
          now,
          [{late_executable, farm_event} | late_exes],
          new_state
        )
    end
  end

  defp check_event(%FarmEvent{} = f, now, last_time) do
    # Get the executable out of the database this may fail.
    mod = Module.safe_concat([f.executable_type])
    executable = lookup!(mod, f)

    # build a local schedule time and end time
    schedule_time = Timex.parse!(f.start_time, "{ISO:Extended}")
    end_time = Timex.parse!(f.end_time, "{ISO:Extended}")

    # get local bool of if the event is scheduled and finished.
    scheduled? = Timex.after?(now, schedule_time)
    finished? = Timex.after?(now, end_time)

    case mod do
      Regimen ->
        maybe_schedule_regimen(
          scheduled?,
          schedule_time,
          last_time,
          executable,
          now
        )

      Sequence ->
        maybe_schedule_sequence(
          scheduled?,
          finished?,
          f,
          last_time,
          executable,
          now
        )
    end
  end

  defp maybe_schedule_regimen(
         scheduled?,
         schedule_time,
         last_time,
         executable,
         now
       )

  defp maybe_schedule_regimen(
         true = _scheduled?,
         schedule_time,
         nil,
         regimen,
         _now
       ) do
    maybe_farm_event_log("regimen #{regimen.name} (#{regimen.id}) scheduling.")
    process_via = Farmbot.Regimen.NameProvider.via(regimen)
    pid = GenServer.whereis(process_via)
    if pid, do: {nil, schedule_time}, else: {regimen, schedule_time}
  end

  defp maybe_schedule_regimen(
         true = _scheduled?,
         _schedule_time,
         last_time,
         event,
         _now
       ) do
    maybe_farm_event_log(
      "regimen #{event.name} (#{event.id}) should already be scheduled."
    )

    {nil, last_time}
  end

  defp maybe_schedule_regimen(
         false = _scheduled?,
         schedule_time,
         last_time,
         event,
         _
       ) do
    maybe_farm_event_log(
      "regimen #{event.name} (#{event.id}) is not scheduled yet. (#{
        inspect(schedule_time)
      }) (#{inspect(Timex.now())})"
    )

    {nil, last_time}
  end

  defp lookup!(module, %FarmEvent{executable_id: exe_id, id: id})
       when is_atom(module) do
    case module do
      Sequence ->
        Asset.get_sequence_by_id!(exe_id)

      Regimen ->
        # We tag the looked up Regimen with the FarmEvent id here.
        # This makes it easier to track the pid of it later when it
        # needs to be scheduled or stopped.
        Asset.get_regimen_by_id!(exe_id, id)
    end
  end

  # signals the start of a sequence based on the described logic.
  defp maybe_schedule_sequence(
         scheduled?,
         finished?,
         farm_event,
         last_time,
         event,
         now
       )

  # We only want to check if the sequence is scheduled, and not finished.
  defp maybe_schedule_sequence(
         true = _scheduled?,
         false = _finished?,
         farm_event,
         last_time,
         event,
         now
       ) do
    {run?, next_time} =
      should_run_sequence?(farm_event.calendar, last_time, now)

    case run? do
      true -> {event, next_time}
      false -> {nil, last_time}
    end
  end

  # if `farm_event.time_unit` is "never" we can't use the `end_time`.
  # if we have no `last_time`, time to execute.
  defp maybe_schedule_sequence(
         true = _scheduled?,
         _,
         %{time_unit: "never"} = f,
         nil = _last_time,
         event,
         now
       ) do
    maybe_farm_event_log("Ignoring end_time.")

    case should_run_sequence?(f.calendar, nil, now) do
      {true, next} -> {event, next}
      {false, _} -> {nil, nil}
    end
  end

  # if scheduled is false, the event isn't ready to be executed.
  defp maybe_schedule_sequence(
         false = _scheduled?,
         _fin,
         _farm_event,
         last_time,
         event,
         _now
       ) do
    maybe_farm_event_log(
      "sequence #{event.name} (#{event.id}) is not scheduled yet."
    )

    {nil, last_time}
  end

  # if the event is finished (but not a "never" time_unit), we don't execute.
  defp maybe_schedule_sequence(
         _scheduled?,
         true = _finished?,
         _farm_event,
         last_time,
         event,
         _now
       ) do
    maybe_farm_event_log("sequence #{event.name} (#{event.id}) is finished.")
    {nil, last_time}
  end

  # Checks  if we shoudl run a sequence or not. returns {event | nil, time | nil}
  defp should_run_sequence?(calendar, last_time, now)

  # if there is no last time, check if time is passed now within 60 seconds.
  defp should_run_sequence?([first_time | _], nil, now) do
    maybe_farm_event_log(
      "Checking sequence event that hasn't run before #{first_time}"
    )

    # convert the first_time to a DateTime
    dt = Timex.parse!(first_time, "{ISO:Extended}")
    # if now is after the time, we are in fact late
    if Timex.after?(now, dt) do
      {true, now}
    else
      # make sure to return nil as the last time because it stil hasnt executed yet.
      maybe_farm_event_log("Sequence Event not ready yet.")
      {false, nil}
    end
  end

  defp should_run_sequence?(nil, last_time, now) do
    maybe_farm_event_log("Checking sequence with no calendar.")

    if is_nil(last_time) do
      {true, now}
    else
      {false, last_time}
    end
  end

  defp should_run_sequence?(calendar, last_time, now) do
    # get rid of all the items that happened before last_time
    filtered_calendar =
      Enum.filter(calendar, fn iso_time ->
        dt = Timex.parse!(iso_time, "{ISO:Extended}")
        # we only want this time if it happened after the last_time
        Timex.after?(dt, last_time)
      end)

    # if after filtering, there are events that need to be run
    # check if they are older than a minute ago,
    case filtered_calendar do
      [iso_time | _] ->
        dt = Timex.parse!(iso_time, "{ISO:Extended}")

        if Timex.after?(now, dt) do
          {true, dt}
        else
          maybe_farm_event_log("Sequence Event not ready yet.")
          {false, dt}
        end

      [] ->
        maybe_farm_event_log("No items in calendar.")
        {false, last_time}
    end
  end

  # Enumeration is complete.
  defp schedule_events([], _now), do: :ok

  # Enumerate the events to be scheduled.
  defp schedule_events([{executable, farm_event} | rest], now) do
    # Spawn to be non blocking here. Maybe link to this process?
    time = Timex.parse!(farm_event.start_time, "{ISO:Extended}")
    cond do
      match?(%Regimen{}, executable) ->
        spawn(Regimen, :schedule_event, [executable, time])
      match?(%Sequence{}, executable) ->
        spawn(Sequence, :schedule_event, [executable, time])
    end

    # Continue enumeration.
    schedule_events(rest, now)
  end

  defp get_now(), do: Timex.now()

  defp maybe_farm_event_log(message) do
    if Application.get_env(:farmbot_core, :farm_event_debug_log) do
      Farmbot.Logger.debug(3, message)
    else
      :ok
    end
  end

  @doc "Enable or disbale debug logs for farmevents."
  def debug_logs(bool \\ true) when is_boolean(bool) do
    Application.put_env(:farmbot_core, :farm_event_debug_log, bool)
  end
end
