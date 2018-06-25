defmodule Farmbot.HTTP.ImageUploader do
  @moduledoc """
  Watches a directory on the File System and uploads images
  """
  use GenServer
  require Farmbot.Logger

  @images_path Path.join(["/", "tmp", "images"])

  @doc """
  Starts the Image Watcher
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Farmbot.Logger.debug 3, "Ensuring #{@images_path} exists."
    Application.stop(:fs)
    Application.put_env(:fs, :path, @images_path)
    File.rm_rf!   @images_path
    File.mkdir_p! @images_path
    :fs_app.start(:normal, [])
    :fs.subscribe()
    {:ok, %{uploads: %{}}}
  end

  def terminate(reason, _state) do
    Farmbot.Logger.debug 3, "Image uploader terminated: #{inspect reason}"
  end

  def handle_info({_pid, {:fs, :file_event}, {path, _}}, state) do
    matches? = matches_any_pattern?(path, [~r{/tmp/images/.*(jpg|jpeg|png|gif)}])
    already_uploading? = Enum.find(state.uploads, fn({_pid, {find_path, _meta, _count}}) ->
      find_path == path
    end) |> is_nil() |> Kernel.!()
    if matches? and (not already_uploading?) do
      Farmbot.Logger.info 2, "Uploading: #{path}"
      %{x: x, y: y, z: z} = Farmbot.BotState.get_current_pos()
      meta = %{x: x, y: y, z: z, name: Path.rootname(path)}
      pid = spawn __MODULE__, :upload, [path, meta]
      Process.monitor(pid)
      {:noreply, %{state | uploads: Map.put(state.uploads, pid, {path, meta, 0})}}
    else
      # Farmbot.Logger.warn 3, "Not uploading: match: #{matches?} already_uploading?: #{already_uploading?}"
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, :normal}, state) do
    case state.uploads[pid] do
      nil -> {:noreply, state}
      {path, _meta, _} ->
        Farmbot.Logger.success 1, "Image Watcher successfully uploaded: #{path}"
        File.rm path
        {:noreply, %{state | uploads: Map.delete(state.uploads, pid)}}
    end
  end

  def handle_info({:DOWN, _, :process, pid, reason}, state) do
    case state.uploads[pid] do
      nil                   -> {:noreply, state}
      {path, _meta, 3 = ret} ->
        Farmbot.Logger.error 1, "Failed to upload #{path} #{ret} times. Giving up."
        File.rm path
        {:noreply, %{state | uploads: Map.delete(state.uploads, pid)}}
      {path, meta, retries}  ->
        if File.exists?(path) do
          Farmbot.Logger.warn 2, "Failed to upload #{path} #{inspect reason}. Going to retry."
          Process.sleep(1000 * retries)
          new_pid = spawn __MODULE__, :upload, [path, meta]
          new_uploads = state.uploads
            |> Map.delete(pid)
            |> Map.put(new_pid, {path, meta, retries + 1})
          Process.monitor(new_pid)
          {:noreply, %{state | uploads: new_uploads}}
        else
          {:noreply, %{state | uploads: Map.delete(state.uploads, pid)}}
        end
    end
  end

  def handle_info(_info, state), do: {:noreply, state}

  # Stolen from
  # https://github.com/phoenixframework/
  #  phoenix_live_reload/blob/151ce9e17c1b4ead79062098b70d4e6bc7c7e528
  #  /lib/phoenix_live_reload/channel.ex#L27
  defp matches_any_pattern?(path, patterns) do
    path = to_string(path)
    if String.contains?(path, "~") do
      false
    else
      Enum.any?(patterns, fn pattern ->
        String.match?(path, pattern)
      end)
    end
  end

  def upload(file_path, meta) do
    Farmbot.Logger.busy 3, "Image Watcher trying to upload #{file_path}"
    case Farmbot.HTTP.upload_file(file_path, meta) do
      {:ok, %{status_code: 200}} -> exit(:normal)
      {:ok, %{body: body}} -> exit({:http_error, body})
      {:error, reason} -> exit(reason)
    end
  end
end
