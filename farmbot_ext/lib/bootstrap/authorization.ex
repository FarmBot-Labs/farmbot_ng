defmodule Farmbot.Bootstrap.Authorization do
  @moduledoc "Functionality responsible for getting a JWT."

  @typedoc "Email used to configure this bot."
  @type email :: binary

  @typedoc "Password used to configure this bot."
  @type password :: binary

  @typedoc "Server used to configure this bot."
  @type server :: binary

  @typedoc "Token that was fetched with the credentials."
  @type token :: binary

  require Farmbot.Logger
  alias Farmbot.Config
  import Config, only: [update_config_value: 4, get_config_value: 3]

  @version Farmbot.Project.version()
  @target Farmbot.Project.target()
  @data_path Application.get_env(:farmbot_ext, :data_path)
  @data_path || raise("No appdata path configured.")

  @doc """
  Callback for an authorization implementation.
  Should return {:ok, token} | {:error, term}
  """
  @callback authorize(email, password, server) :: {:ok, token} | {:error, term}

  # this is the default authorize implementation.
  # It gets overwrote in the Test Environment.
  @doc "Authorizes with the farmbot api."
  def authorize(email, pw_or_secret, server) do
    case get_config_value(:bool, "settings", "first_boot") do
      false -> authorize_with_secret(email, pw_or_secret, server)
      true -> authorize_with_password(email, pw_or_secret, server)
    end
    |> case do
      {:ok, token} -> {:ok, token}
      err ->
        Farmbot.Logger.error 1, "Authorization failed: #{inspect err}"
        err
    end
  end

  def authorize_with_secret(email, secret, server, state \\ %{backoff: 5000, logged_once: false})

  def authorize_with_secret(email, secret, server, state) do
    with {:ok, payload} <- build_payload(secret),
         {:ok, resp}    <- request_token(server, payload),
         {:ok, body}    <- Farmbot.JSON.decode(resp),
         {:ok, map}     <- Map.fetch(body, "token") do
      last_reset_reason_file = Path.join(@data_path, "last_shutdown_reason")
      File.rm(last_reset_reason_file)
      Map.fetch(map, "encoded")
    else
      :error -> {:error, "unknown error."}
      {:error, :invalid, _} -> authorize_with_secret(email, secret, server, state)
      # If we got maintance mode, a 5xx error etc,
      # just sleep for a few seconds
      # and try again.
      # There is some state data here to allow for a backoff timer.
      # This means in cases of the api serving 5xx's because it is overloaded,
      # We are not going to be adding way more to the load.
      # We also only log this as an error once, to ensure the database doesn't
      # get full of logs.
      {:error, {:http_error, code}} ->
        msg = "Failed to authorize due to server error: #{code}. Trying again in #{state.backoff / 1000} seconds."
        if state.logged_once, do: Farmbot.Logger.debug(3, msg), else: Farmbot.Logger.error(1, msg)
        Process.sleep(state.backoff)
        new_state = %{state | backoff: state.backoff + 1000, logged_once: true}
        authorize_with_secret(email, secret, server, new_state)
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
      err -> err
    end
  end

  def authorize_with_password(email, password, server) do
    with {:ok, {:RSAPublicKey, _, _} = rsa_key} <- fetch_rsa_key(server),
         {:ok, payload} <- build_payload(email, password, rsa_key),
         {:ok, resp}    <- request_token(server, payload),
         {:ok, body}    <- Farmbot.JSON.decode(resp),
         {:ok, map}     <- Map.fetch(body, "token") do
      update_config_value(:bool, "settings", "first_boot", false)
      last_reset_reason_file = Path.join(@data_path, "last_shutdown_reason")
      File.rm(last_reset_reason_file)
      Map.fetch(map, "encoded")
    else
      :error -> {:error, "unknown error."}
      {:error, :invalid, _} -> authorize(email, password, server)
      # If we got maintance mode, a 5xx error etc,
      # just sleep for a few seconds
      # and try again.
      {:error, {:http_error, code}} ->
        Farmbot.Logger.error 1, "Failed to authorize due to server error: #{code}"
        Process.sleep(5000)
        authorize(email, password, server)
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
      err -> err
    end
  end

  def fetch_rsa_key(server) do
    url = "#{server}/api/public_key"
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        r = body |> to_string() |> RSA.decode_key()
        {:ok, r}
      {:ok, %{status_code: code, body: body}} ->
        msg = """
        Failed to fetch public key.
        status_code: #{code}
        body: #{inspect body}
        """
        {:error, msg}
      {:error, reason} -> {:error, reason}
    end
  end

  def build_payload(email, password, rsa_key) do
    secret =
      %{email: email, password: password, id: UUID.uuid1(), version: 1}
      |> Farmbot.JSON.encode!()
      |> RSA.encrypt({:public, rsa_key})
    update_config_value(:string, "authorization", "password", secret)
    %{user: %{credentials: secret |> Base.encode64()}} |> Farmbot.JSON.encode()
  end

  defp build_payload(secret) do
    user = %{credentials: secret |> :base64.encode_to_string |> to_string}
    Farmbot.JSON.encode(%{user: user})
  end

  def request_token(server, payload) do
    headers = [
      {"User-Agent", "FarmbotOS/#{@version} (#{@target}) #{@target} ()"},
      {"Content-Type", "application/json"}
    ]
    case HTTPoison.post("#{server}/api/tokens", payload, headers) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}

      # if the error is a 4xx code, it was a failed auth.
      {:ok, %{status_code: code, body: body}} when code > 399 and code < 500 ->
        reason = get_body(body)
        msg = """
        Failed to authorize with the Farmbot web application at: #{server}
        with code: #{code}
        body: #{reason}
        """
        {:error, msg}

      # if the error is not 2xx and not 4xx, probably maintance mode.
      {:ok, %{status_code: code}} -> {:error, {:http_error, code}}
      {:error, error} -> {:error, error}
    end
  end

  defp get_body(body) do
    case Farmbot.JSON.decode(body) do
      {:ok, %{"auth" => reason}} -> reason
      {:ok, reason} -> inspect reason
      _ -> inspect body
    end
  end
end
