defmodule Farmbot.Bootstrap.Authorization do
  @moduledoc "Functionality responsible for getting a JWT."

  @typedoc "Email used to configure this bot."
  @type email :: String.t

  @typedoc "Password used to configure this bot."
  @type password :: binary

  @typedoc "Password hash."
  @type secret :: binary

  @typedoc "Server used to configure this bot."
  @type server :: String.t

  @typedoc "Token that was fetched with the credentials."
  @type token :: binary

  require Farmbot.Logger

  @version Farmbot.Project.version()
  @target Farmbot.Project.target()
  @data_path Application.get_env(:farmbot_ext, :data_path)
  @data_path || raise("No appdata path configured.")

  @spec authorize_with_secret(email, secret, server) :: {:ok, binary} | {:error, String.t | atom}
  def authorize_with_secret(_email, secret, server) do
    with {:ok, payload} <- build_payload(secret),
         {:ok, resp}    <- request_token(server, payload),
         {:ok, body}    <- Farmbot.JSON.decode(resp) do
           get_encoded(body)
         end
  end

  @spec authorize_with_password(email, password, server) :: {:ok, binary} | {:error, String.t | atom}
  def authorize_with_password(email, password, server) do
    with {:ok, {:RSAPublicKey, _, _} = rsa_key} <- fetch_rsa_key(server),
         {:ok, payload} <- build_payload(email, password, rsa_key),
         {:ok, resp}    <- request_token(server, payload),
         {:ok, body}    <- Farmbot.JSON.decode(resp) do
           get_encoded(body)
         end
  end

  defp get_encoded(%{"token" => %{"encoded" => encoded}}), do: {:ok, encoded}
  defp get_encoded(_), do: {:error, :bad_response}

  def build_payload(email, password, rsa_key) do
    build_secret(email, password, rsa_key)
    |> build_payload()
  end

  defp build_payload(secret) do
    %{user: %{credentials: secret |> Base.encode64()}}
    |> Farmbot.JSON.encode()
  end

  defp build_secret(email, password, rsa_key) do
    %{email: email, password: password, id: UUID.uuid1(), version: 1}
    |> Farmbot.JSON.encode!()
    |> RSA.encrypt({:public, rsa_key})
  end

  @headers [
    {"User-Agent", "FarmbotOS/#{@version} (#{@target}) #{@target} ()"},
    {"Content-Type", "application/json"}
  ]

  @spec fetch_rsa_key(server) :: {:ok, term} | {:error, String.t | atom}
  def fetch_rsa_key(server) do
    url = "#{server}/api/public_key"
    with {:ok, body} <- request({:get, url, "", @headers}) do
      {:ok, RSA.decode_key(body)}
    end
  end

  @spec request_token(server, binary) :: {:ok, binary} | {:error, String.t | atom}
  def request_token(server, payload) do
    url = "#{server}/api/tokens"
    request({:post, url, payload, @headers})
  end

  def request(request, state \\ %{backoff: 5000, log_dispatch_flag: false})

  def request({method, url, payload, headers}, state) do
    case HTTPoison.request(method, url, payload, headers) do
      {:ok, %{status_code: c, body: body}} when (c >= 200) and (c <= 299) ->
        IO.inspect(body, label: "successful request")
        {:ok, body}
      {:ok, %{status_code: c, body: body}} when (c >= 400) and (c <= 499) ->
        err = get_error_message(body)
        Farmbot.Logger.error 1, "Authorization error for url: #{url} #{err}"
        {:error, err}
      {:ok, %{status_code: c, body: body}} when (c >= 500) and (c <= 599) ->
        Process.sleep(state.backoff)
        unless state.log_dispatch_flag do
          err = get_error_message(body)
          Farmbot.Logger.warn 1, "Farmbot web app failed complete request for url: #{url} #{err}"
        end
        request({method, url, payload, headers}, %{state | backoff: state.backoff + 1000, log_dispatch_flag: true})
      {:error, %{reason: reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_error_message(binary) :: String.t
  defp get_error_message(bin) when is_binary(bin) do
    case Farmbot.JSON.decode(bin) do
      {:ok, %{"auth" => reason}} when is_binary(reason) -> reason
      _ -> bin
    end
  end
end
