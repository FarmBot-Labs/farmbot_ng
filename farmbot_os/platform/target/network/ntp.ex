defmodule Farmbot.Target.Network.Ntp do
  @moduledoc """
  Sets time.
  """

  # TODO(Connor) Make dns server configurable

  require Farmbot.Logger
  import Farmbot.Target.Network, only: [test_dns: 1]

  @doc """
  Tries to set the time from ntp.
  This will try 3 times to set the time. if it fails the thrid time,
  it will return an error
  """
  def set_time(tries \\ 0)
  def set_time(tries) when tries < 4 do
    Process.sleep(1000 * tries)
    case test_dns('0.pool.ntp.org') do
      {:ok, {:hostent, _url, _, _, _, _}} ->
        do_try_set_time(tries)
      {:error, err} ->
        Farmbot.Logger.error 1, "Failed to set time (#{tries}): DNS Lookup: #{inspect err}"
        set_time(tries + 1)
    end
  end

  def set_time(_), do: {:error, :timeout}

  defp do_try_set_time(tries) when tries < 4 do
    # we try to set ntp time 3 times before giving up.
    # Farmbot.Logger.busy 3, "Trying to set time (try #{tries})"
    :os.cmd('ntpd -q -p 0.pool.ntp.org -p 1.pool.ntp.org')
    wait_for_time(tries)
  end

  defp wait_for_time(tries, loops \\ 0)

  defp wait_for_time(tries, loops) when loops > 5 do
    :os.cmd('killall ntpd')
    set_time(tries)
  end

  defp wait_for_time(tries, loops) do
    case :os.system_time(:seconds) do
      t when t > 1_474_929 ->
        # Farmbot.Logger.success 2, "Time is set."
        # Farmbot.Logger.busy 2, "Updating tzdata."
        update_tzdata()
      _ ->
        Process.sleep(1_000 * loops)
        wait_for_time(tries, loops + 1)
    end
  end

  defp update_tzdata(retries \\ 0)

  defp update_tzdata(retries) when retries > 5 do
    Farmbot.Logger.error 1, "Failed too update tzdata!"
    {:error, :failed_to_update_tzdata}
  end

  defp update_tzdata(retries) do
    maybe_hack_tzdata()
    case Tzdata.DataLoader.download_new() do
      {:ok, _, _, _, _} ->
        # Farmbot.Logger.success 3, "Successfully updated tzdata."
        :ok
      _ -> update_tzdata(retries + 1)
    end
  end

  @fb_data_dir Application.get_env(:farmbot_ext, :data_path)
  @tzdata_dir Application.app_dir(:tzdata, "priv")
  def maybe_hack_tzdata do
    case Tzdata.Util.data_dir() do
      @fb_data_dir -> :ok
      _ ->
        Farmbot.Logger.warn 3, "Hacking tzdata."
        objs_to_cp = Path.wildcard(Path.join(@tzdata_dir, "*"))
        for obj <- objs_to_cp do
          File.cp_r obj, @fb_data_dir
        end
        Application.put_env(:tzdata, :data_dir, @fb_data_dir)
        :ok
    end
  end

end
