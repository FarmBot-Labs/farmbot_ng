defmodule Farmbot.Firmware.UartHandler.AutoDetector do
  @moduledoc """
  Init module for configuring a UART handler. Here's what it does:

  * Enumerates Serial devices
  * Scrubs devices that should be ignored.
  * If there is *ONE* device:
    * Configures Farmbot.Behaviour.FirmwareHandler -> UartHandler
    * Configures the device to be used.
  * If there are zero or more than one device:
    * Configures Farmbot.Behaviour.FirmwareHandler -> StubHandler
  """

  alias Nerves.UART
  alias Farmbot.Firmware.{UartHandler, StubHandler, Utils}
  import Utils
  require Farmbot.Logger

  #TODO(Connor) - Maybe make this configurable?
  @ignore_devs ["ttyAMA0", "ttyS0", "ttyS3"]

  @doc "Autodetect relevent UART Devs."
  def auto_detect do
    UART.enumerate() |> Map.keys() |> Kernel.--(@ignore_devs)
  end

  @doc false
  def start_link(_, _) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    update_env()
    :ignore
  end

  def update_env do
    case auto_detect() do
      [dev] ->
        dev = "/dev/#{dev}"
        Farmbot.Logger.success 3, "detected target UART: #{dev}"
        replace_firmware_handler(UartHandler)
        Application.put_env(:farmbot_core, :uart_handler, tty: dev)
        dev
      _ ->
        Farmbot.Logger.error 1, "Could not detect a UART device."
        replace_firmware_handler(StubHandler)
        :error
    end
  end
end
