defmodule Farmbot.Firmware.UartHandler do
  @moduledoc """
  Handles communication between farmbot and uart devices
  """

  use GenStage
  alias Nerves.UART
  require Farmbot.Logger
  import Farmbot.Config, only: [update_config_value: 4, get_config_value: 3]
  alias Farmbot.Firmware
  alias Firmware.Utils
  import Utils

  @behaviour Firmware.Handler

  def start_link do
    GenStage.start_link(__MODULE__, [])
  end

  def move_absolute(handler, pos, x_speed, y_speed, z_speed) do
    GenStage.call(handler, {:move_absolute, pos, x_speed, y_speed, z_speed})
  end

  def calibrate(handler, axis) do
    GenStage.call(handler, {:calibrate, axis})
  end

  def find_home(handler, axis) do
    GenStage.call(handler, {:find_home, axis})
  end

  def home(handler, axis) do
    GenStage.call(handler, {:home, axis})
  end

  def home_all(handler) do
    GenStage.call(handler, :home_all)
  end

  def zero(handler, axis) do
    GenStage.call(handler, {:zero, axis})
  end

  def update_param(handler, param, val) do
    GenStage.call(handler, {:update_param, param, val})
  end

  def read_param(handler, param) do
    GenStage.call(handler, {:read_param, param})
  end

  def read_all_params(handler) do
    GenStage.call(handler, :read_all_params)
  end

  def emergency_lock(handler) do
    GenStage.call(handler, :emergency_lock)
  end

  def emergency_unlock(handler) do
    GenStage.call(handler, :emergency_unlock)
  end

  def set_pin_mode(handler, pin, mode) do
    GenStage.call(handler, {:set_pin_mode, pin, mode})
  end

  def read_pin(handler, pin, pin_mode) do
    GenStage.call(handler, {:read_pin, pin, pin_mode})
  end

  def write_pin(handler, pin, pin_mode, value) do
    GenStage.call(handler, {:write_pin, pin, pin_mode, value})
  end

  def request_software_version(handler) do
    GenStage.call(handler, :request_software_version)
  end

  def set_servo_angle(handler, pin, number) do
    GenStage.call(handler, {:set_servo_angle, pin, number})
  end

  ## Private

  defmodule State do
    @moduledoc false
    defstruct [
      nerves: nil,
      current_cmd: nil,
      tty: nil,
      hw: nil
    ]
  end

  def init([]) do
    Farmbot.Logger.debug 3, "Uart handler init."
    # If in dev environment,
    #   it is expected that this be done at compile time.
    # If in target environment,
    #   this should be done by `Farmbot.Firmware.AutoDetector`.
    error_msg = "Please configure uart handler!"
    tty = Application.get_env(:farmbot_core, :uart_handler)[:tty] || raise error_msg

    # Disable fw input logs after a reset of the
    # Fw handler if they were enabled.
    update_config_value(:bool, "settings", "firmware_input_log", false)
    hw = get_config_value(:string, "settings", "firmware_hardware")
    gen_stage_opts = [
      dispatcher: GenStage.BroadcastDispatcher,
      subscribe_to: [ConfigStorage.Dispatcher]
    ]
    case open_tty(tty) do
      {:ok, nerves} ->
        {:producer_consumer, %State{nerves: nerves, tty: tty, hw: hw}, gen_stage_opts}
      err ->
        {:stop, err}
    end
  end

  def handle_events(events, _, state) do
    state = Enum.reduce(events, state, fn(event, state_acc) ->
      handle_config(event, state_acc)
    end)

    case state do
      %State{} = state ->
        {:noreply, [], state}
      _ -> state
    end
  end

  defp handle_config({:config, "settings", key, _val}, state)
    when key in ["firmware_input_log", "firmware_output_log"]
  do
    # Restart the framing to pick up new changes.
    UART.configure state.nerves, [framing: UART.Framing.None, active: false]
    configure_uart(state.nerves, true)
    state
  end

  defp handle_config({:config, "settings", "firmware_hardware", _val}, _state) do
    raise("FIXME")
  end

  defp handle_config(_, state) do
    state
  end

  defp open_tty(tty, nerves \\ nil) do
    Farmbot.Logger.debug 3, "Opening uart device: #{tty}"
    nerves = nerves || UART.start_link |> elem(1)
    Process.link(nerves)
    case UART.open(nerves, tty, [speed: 115_200, active: true]) do
      :ok ->
        :ok = configure_uart(nerves, true)
        # Flush the buffers so we start fresh
        :ok = UART.flush(nerves)
        loop_until_idle(nerves)
      err ->
        err
    end
  end

  defp loop_until_idle(nerves, idle_count \\ 0)

  defp loop_until_idle(nerves, 2) do
    Farmbot.Logger.success 3, "Got two idles. UART is up."
    Process.sleep(1500)
    {:ok, nerves}
  end

  defp loop_until_idle(nerves, idle_count)
    when is_pid(nerves) and is_number(idle_count)
  do
    Farmbot.Logger.debug 3, "Waiting for firmware idle."
    receive do
      {:nerves_uart, _, {:error, reason}} -> {:stop, reason}
      {:nerves_uart, _, {:partial, _}} -> loop_until_idle(nerves, idle_count)
      {:nerves_uart, _, {_, :idle}} -> loop_until_idle(nerves, idle_count + 1)
      {:nerves_uart, _, {_, {:debug_message, msg}}} ->
        if String.contains?(msg, "STARTUP") do
          Farmbot.Logger.success 3, "Got #{msg}. UART is up."
          {:ok, nerves}
        else
          Farmbot.Logger.debug 3, "Got arduino debug while booting up: #{msg}"
          loop_until_idle(nerves, idle_count)
        end
      {:nerves_uart, _, _msg} -> loop_until_idle(nerves, idle_count)
    after
      10_000 -> {:stop, "Firmware didn't send any info for 10 seconds."}
    end
  end

  defp configure_uart(nerves, active) do
    UART.configure(
      nerves,
      framing: {Farmbot.Firmware.UartHandler.Framing, separator: "\r\n"},
      active: active,
      rx_framing_timeout: 500
    )
  end

  def terminate(reason, state) do
    Farmbot.Logger.warn 1, "UART handler died: #{inspect reason}"
    if state.nerves do
      UART.close(state.nerves)
      UART.stop(:normal)
    end
  end

  # if there is an error, we assume something bad has happened, and we probably
  # Are better off crashing here, and being restarted.
  def handle_info({:nerves_uart, _, {:error, :eio}}, state) do
    Farmbot.Logger.error 1, "UART device removed."
    old_env = Application.get_env(:farmbot_core, :behaviour)
    new_env = Keyword.put(old_env, :firmware_handler, Firmware.StubHandler)
    Application.put_env(:farmbot_core, :behaviour, new_env)
    {:stop, {:error, :eio}, state}
  end

  def handle_info({:nerves_uart, _, {:error, reason}}, state) do
    {:stop, {:error, reason}, state}
  end

  # Unhandled gcodes just get ignored.
  def handle_info({:nerves_uart, _, {:unhandled_gcode, code_str}}, state) do
    Farmbot.Logger.debug 3, "Got unhandled gcode: #{code_str}"
    {:noreply, [], state}
  end

  def handle_info({:nerves_uart, _, {_, {:report_software_version, v}}}, state) do
    expected = Application.get_env(:farmbot_core, :expected_fw_versions)
    if v in expected do
      {:noreply, [{:report_software_version, v}], state}
    else
      err = "Firmware version #{v} is not in expected versions: #{inspect expected}"
      Farmbot.Logger.error 1, err
      old_env = Application.get_env(:farmbot_core, :behaviour)
      new_env = Keyword.put(old_env, :firmware_handler, Firmware.StubHandler)
      Application.put_env(:farmbot_core, :behaviour, new_env)
      {:stop, :normal, state}
    end
  end

  def handle_info({:nerves_uart, _, {:echo, _}}, %{current_cmd: nil} = state) do
    {:noreply, [], state}
  end
  def handle_info({:nerves_uart, _, {:echo, {:echo, "*F43" <> _}}}, state) do
    {:noreply, [], state}
  end

  def handle_info({:nerves_uart, _, {:echo, {:echo, code}}}, state) do
    distance = String.jaro_distance(state.current_cmd, code)
    if distance > 0.85 do
      :ok
    else
      err = "Echo #{code} does not match #{state.current_cmd} (#{distance})"
      Farmbot.Logger.error 3, err
    end
    {:noreply, [], %{state | current_cmd: nil}}
  end

  def handle_info({:nerves_uart, _, {_q, :done}}, state) do
    {:noreply, [:done], %{state | current_cmd: nil}}
  end

  def handle_info({:nerves_uart, _, {_q, gcode}}, state) do
    {:noreply, [gcode], state}
  end

  def handle_info({:nerves_uart, _, bin}, state) when is_binary(bin) do
    Farmbot.Logger.warn(3, "Unparsed Gcode: #{bin}")
    {:noreply, [], state}
  end

  defp do_write(bin, state, dispatch \\ []) do
    # Farmbot.Logger.debug 3, "writing: #{bin}"
    case UART.write(state.nerves, bin) do
      :ok -> {:reply, :ok, dispatch, %{state | current_cmd: bin}}
      err -> {:reply, err, [], %{state | current_cmd: nil}}
    end
  end

  def handle_call({:move_absolute, pos, x_speed, y_speed, z_speed}, _from, state) do
    cmd = "X#{fmnt_float(pos.x)} "
       <> "Y#{fmnt_float(pos.y)} "
       <> "Z#{fmnt_float(pos.z)} "
       <> "A#{fmnt_float(x_speed)} "
       <> "B#{fmnt_float(y_speed)} "
       <> "C#{fmnt_float(z_speed)}"
    wrote = "G00 #{cmd}"
    do_write(wrote, state)
  end

  def handle_call({:calibrate, axis}, _from, state) do
    num = case axis |> to_string() do
      "x" -> 14
      "y" -> 15
      "z" -> 16
    end
    do_write("F#{num}", state)
  end

  def handle_call({:find_home, axis}, _from, state) do
    cmd = case axis |> to_string() do
      "x" -> "11"
      "y" -> "12"
      "z" -> "13"
    end
    do_write("F#{cmd}", state)
  end

  def handle_call(:home_all, _from, state) do
    do_write("G28", state)
  end

  def handle_call({:home, axis}, _from, state) do
    cmd = case axis |> to_string() do
      "x" -> "X0"
      "y" -> "Y0"
      "z" -> "Z0"
    end
    do_write("G00 #{cmd}", state)
  end

  def handle_call({:zero, axis}, _from, state) do
    axis_format = case axis |> to_string() do
      "x" -> "X"
      "y" -> "Y"
      "z" -> "Z"
    end
    do_write("F84 #{axis_format}1", state)
  end

  def handle_call(:emergency_lock, _from, state) do
    r = UART.write(state.nerves, "E")
    {:reply, r, [], state}
  end

  def handle_call(:emergency_unlock, _from, state) do
    do_write("F09", state)
  end

  def handle_call({:read_param, param}, _from, state) do
    num = Farmbot.Firmware.Gcode.Param.parse_param(param)
    do_write("F21 P#{num}", state)
  end

  def handle_call({:update_param, param, val}, _from, state) do
    num = Farmbot.Firmware.Gcode.Param.parse_param(param)
    do_write("F22 P#{num} V#{val}", state)
  end

  def handle_call(:read_all_params, _from, state) do
    do_write("F20", state)
  end

  def handle_call({:set_pin_mode, pin, mode_atom}, _from, state) do
    encoded_mode = extract_set_pin_mode(mode_atom)
    do_write("F43 P#{pin} M#{encoded_mode}", state, [])
  end

  def handle_call({:read_pin, pin, mode}, _from, state) do
    encoded_mode = extract_pin_mode(mode)
    dispatch = [{:report_pin_mode, pin, mode}]
    do_write("F42 P#{pin} M#{encoded_mode}", state, dispatch)
  end

  def handle_call({:write_pin, pin, mode, value}, _from, state) do
    encoded_mode = extract_pin_mode(mode)
    dispatch = [{:report_pin_mode, pin, mode}, {:report_pin_value, pin, value}]
    do_write("F41 P#{pin} V#{value} M#{encoded_mode}", state, dispatch)
  end

  def handle_call(:request_software_version, _from, state) do
    do_write("F83", state)
  end

  def handle_call({:set_servo_angle, pin, angle}, _, state) do
    do_write("F61 P#{pin} V#{angle}", state)
  end

  def handle_call(_call, _from, state) do
    {:reply, {:error, :bad_call}, [], state}
  end

  def handle_demand(_amnt, state) do
    {:noreply, [], state}
  end
end
