defmodule Farmbot.Bootstrap.Supervisor do
  @moduledoc """
  Bootstraps the application.

  It is expected that there is authorization credentials in the application's
  environment by this point. This can be configured via a `Farmbot.Init` module.

  For example:

  # config.exs
      use Mix.Config

      config :farmbot_ext, :init, [
        Farmbot.Configurator
      ]

      config :farmbot_ext, :behaviour,
        authorization: Farmbot.Configurator

  # farmbot_configurator.ex

      defmodule Farmbot.Configurator do
        @moduledoc false
        @behaviour Farmbot.System.Init
        @behaviour Farmbot.Bootstrap.Authorization

        # Callback for Farmbot.System.Init.
        # This can return {:ok, pid} if it should be a supervisor.
        def start_link(_args, _opts) do
          creds = [
            email: "some_user@some_server.org",
            password: "some_secret_password_dont_actually_store_in_plain_text",
            server:   "https://my.farmbot.io"
          ]
          Application.put_env(:farmbot_ext, :behaviour, creds)
          :ignore
        end

        # Callback for Farmbot.Bootstrap.Authorization.
        # Should return `{:ok, token}` where `token` is a binary jwt, or
        # {:error, reason} reason can be anything, but a binary is easiest to
        # Parse.
        def authorize(email, password, server) do
          # some intense http stuff or whatever.
          {:ok, token}
        end
      end

  This will cause the `creds` to be stored in the application's environment.
  This moduld then will try to use the configured module to `authorize`.

  If either of these things error, the bot try to factory reset
  """

  use Supervisor
  alias Farmbot.Bootstrap.Authorization, as: Auth
  alias Farmbot.Config
  import Config, only: [update_config_value: 4, get_config_value: 3]
  require Farmbot.Logger

  error_msg = """
  Please configure an authorization module!
  for example:
      config: :farmbot_ext, :behaviour, [
        authorization: Farmbot.Bootstrap.Authorization
      ]
  """

  @auth_task Application.get_env(:farmbot_ext, :behaviour)[:authorization]
  @auth_task || Mix.raise(error_msg)

  @doc "Start Bootstrap services."
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, [name: __MODULE__])
  end

  def init([]) do
    Farmbot.Config.update_config_value(:string, "authorization", "email", "connor@farmbot.io")
    Farmbot.Config.update_config_value(:string, "authorization", "password", "password1234")
    Farmbot.Config.update_config_value(:string, "authorization", "server", "https://my.farmbot.io")
    Farmbot.Config.update_config_value(:bool, "settings", "first_boot", true)
    # Make sure we log when amqp is connected.
    update_config_value(:bool, "settings", "log_amqp_connected", true)

    # try to find the creds.
    case get_creds() do
      # do the actual supervisor init if we have creds. This may still fail.
      {email, pass, server} ->
        actual_init(email, pass, server)

      # This will cause a factory reset.
      {:error, reason} ->
        {:error, reason}
    end
  end

  @typedoc "Authorization credentials."
  @type auth :: {Auth.email(), Auth.password(), Auth.server()}

  @spec get_creds() :: auth | {:error, term}
  defp get_creds do
    try do
      # Fetch email, server, password from Storage.
      email = get_config_value(:string, "authorization", "email")
      pass = get_config_value(:string, "authorization", "password")
      server = get_config_value(:string, "authorization", "server")

      # Make sure they aren't empty.
      email  || raise "Could not find email in configuration. "
      pass   || raise "No password provided in config storage."
      server || raise "No server provided in config storage."
      {email, pass, server}
    rescue
      e in RuntimeError -> {:error, Exception.message(e)}
      e -> reraise(e, System.stacktrace())
    end
  end

  defp actual_init(email, pass, server) do
    busy_msg = "Beginning Bootstrap authorization: #{email} - #{server}"
    Farmbot.Logger.busy(2, busy_msg)
    # get a token
    case @auth_task.authorize(email, pass, server) do
      {:ok, token} ->
        success_msg = "Successful Bootstrap authorization: #{email} - #{server}"
        Farmbot.Logger.success(2, success_msg)
        update_config_value(:bool, "settings", "first_boot", false)
        update_config_value(:string, "authorization", "token", token)

        children = [
          {Farmbot.HTTP.Supervisor,    []},
          {Farmbot.SettingsSync,       []},
          {Farmbot.AMQP.Supervisor ,   []},
          {Farmbot.Bootstrap.AuthTask, []}
        ]

        opts = [strategy: :one_for_one]
        Supervisor.init(children, opts)

      {:error, reason} -> {:error, reason}
    end
  end
end
