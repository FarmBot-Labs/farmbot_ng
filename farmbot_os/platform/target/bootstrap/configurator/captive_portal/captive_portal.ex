defmodule Farmbot.Target.Bootstrap.Configurator.CaptivePortal do
  use GenServer
  use Farmbot.Logger

  @interface Application.get_env(:farmbot, :captive_portal_interface, "wlan0")
  @address Application.get_env(:farmbot, :captive_portal_address, "192.168.25.1")

  @dnsmasq_conf_file "dnsmasq.conf"
  @dnsmasq_pid_file "dnsmasq.pid"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Logger.busy(3, "Starting captive portal.")
    ensure_interface(@interface)

    Nerves.Network.teardown(@interface)

    host_ap_opts = [
      ssid: build_ssid(),
      key_mgmt: :NONE,
      mode: 2,
      # ap_scan: 0,
      # scan_ssid: 1,
    ]
    Nerves.Network.setup(@interface, host_ap_opts)

    ip_opts = [
      ipv4_address_method: :static,
      ipv4_address: @address, ipv4_subnet_mask: "255.255.0.0",
      nameservers: [@address]
    ]

    Nerves.NetworkInterface.setup(@interface, ip_opts)

    dhcp_opts = [
      gateway: @address,
      netmask: "255.255.255.0",
      range: {dhcp_range_begin(@address), dhcp_range_end(@address)},
      domain_servers: [@address],
    ]
    {:ok, dhcp_server} = DHCPServer.start_link(@interface, dhcp_opts)

    dnsmasq = setup_dnsmasq(@address, @interface)

    wpa_pid = wait_for_wpa()
    Nerves.WpaSupplicant.request(wpa_pid, {:AP_SCAN, 2})
    {:ok, %{dhcp_server: dhcp_server, dnsmasq: dnsmasq}}
  end

  defp wait_for_wpa do
    name = :"Nerves.WpaSupplicant.#{@interface}"
    GenServer.whereis(name) || wait_for_wpa()
  end

  def terminate(_, state) do
    Logger.busy 3, "Stopping captive portal GenServer."

    Logger.busy 3, "Stopping DHCP GenServer."
    GenServer.stop(state.dhcp_server, :normal)

    stop_dnsmasq(state)

    Nerves.Network.teardown(@interface)
    Nerves.NetworkInterface.ifdown(@interface)
    do_teardown(@interface)
  end

  defp do_teardown(interface) do
    case Nerves.NetworkInterface.status(interface) do
      {:ok, %{operstate: :down}} -> :ok
      {:ok, %{operstate: :up}} ->
        Logger.busy 3, "Trying to stop #{interface}."
        Process.sleep(1000)
        Nerves.NetworkInterface.ifdown(interface)
        do_teardown(interface)
    end
  end

  def handle_info({_port, {:data, _data}}, state) do
    {:noreply, state}
  end

  defp dhcp_range_begin(address) do
    [a, b, c, _] = String.split(address, ".")
    Enum.join([a, b, c, "2"], ".")
  end

  defp dhcp_range_end(address) do
    [a, b, c, _] = String.split(address, ".")
    Enum.join([a, b, c, "10"], ".")
  end

  defp ensure_interface(interface) do
    unless interface in Nerves.NetworkInterface.interfaces() do
      Logger.debug 2, "Waiting for #{interface}: #{inspect Nerves.NetworkInterface.interfaces()}"
      Process.sleep(100)
      ensure_interface(interface)
    end
  end

  defp build_ssid do
    node_str = node() |> Atom.to_string()
    case node_str |> String.split("@") do
      [name, "farmbot-" <> id] -> name <> "-" <> id
      _ -> "Farmbot"
    end
  end

  defp setup_dnsmasq(ip_addr, interface) do
    dnsmasq_conf = build_dnsmasq_conf(ip_addr, interface)
    File.mkdir!("/tmp/dnsmasq")
    :ok = File.write("/tmp/dnsmasq/#{@dnsmasq_conf_file}", dnsmasq_conf)
    dnsmasq_cmd = "dnsmasq -k --dhcp-lease " <>
                  "/tmp/dnsmasq/#{@dnsmasq_pid_file} " <>
                  "--conf-dir=/tmp/dnsmasq"
    dnsmasq_port = Port.open({:spawn, dnsmasq_cmd}, [:binary])
    dnsmasq_os_pid = dnsmasq_port|> Port.info() |> Keyword.get(:os_pid)
    {dnsmasq_port, dnsmasq_os_pid}
  end

  defp build_dnsmasq_conf(ip_addr, interface) do
    """
    interface=#{interface}
    address=/#/#{ip_addr}
    server=/farmbot/#{ip_addr}
    local=/farmbot/
    domain=farmbot
    """
  end

  defp stop_dnsmasq(state) do
    case state.dnsmasq do
      {dnsmasq_port, dnsmasq_os_pid} ->
        Logger.busy 3, "Stopping dnsmasq"
        Logger.busy 3, "Killing dnsmasq PID."
        :ok = kill(dnsmasq_os_pid)
        Port.close(dnsmasq_port)
        Logger.success 3, "Stopped dnsmasq."
        :ok
      _ ->
        Logger.debug 3, "Dnsmasq not running."
        :ok
    end
  rescue
    e ->
      Logger.error 3, "Error stopping dnsmasq: #{Exception.message(e)}"
      :ok
  end

  defp kill(os_pid), do: :ok = cmd("kill -9 #{os_pid}")

  defp cmd(cmd_str) do
    [command | args] = String.split(cmd_str, " ")
    System.cmd(command, args, into: IO.stream(:stdio, :line))
    |> print_cmd()
  end

  defp print_cmd({_, 0}), do: :ok

  defp print_cmd({_, num}) do
    Logger.error(2, "Encountered an error (#{num})")
    :error
  end

end
