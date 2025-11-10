import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/voile start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :voile, VoileWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      System.get_env("VOILE_DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :voile, Voile.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    # Set timezone to Indonesia (GMT+7) for production
    parameters: [timezone: "Asia/Jakarta"]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("VOILE_SECRET_KEY") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :voile, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :voile, VoileWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: [
      "//localhost:4000",
      "//127.0.0.1:4000",
      "//pustaka.unpad.ac.id",
      "//#{host}"
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :voile, VoileWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :voile, VoileWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :voile, Voile.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  # Turnstile Configuration
  config :phoenix_turnstile,
    site_key: System.fetch_env!("VOILE_TURNSTILE_SITE_KEY"),
    secret_key: System.fetch_env!("VOILE_TURNSTILE_SECRET_KEY")

  # Configure mailer for production
  # Supports both SMTP (Google Workspace, self-hosted) and API-based providers
  mailer_adapter = System.get_env("VOILE_MAILER_ADAPTER") || "smtp"

  case mailer_adapter do
    "gmail_api" ->
      # Gmail API Configuration (OAuth2)
      # This is more secure than SMTP with app passwords
      config :voile, Voile.Mailer,
        adapter: Voile.Mailer.GmailApiAdapter,
        access_token: System.get_env("VOILE_GMAIL_ACCESS_TOKEN"),
        refresh_token: System.get_env("VOILE_GMAIL_REFRESH_TOKEN"),
        client_id: System.get_env("VOILE_GMAIL_CLIENT_ID"),
        client_secret: System.get_env("VOILE_GMAIL_CLIENT_SECRET"),
        redirect_uri: System.get_env("VOILE_GMAIL_REDIRECT_URI")

    "smtp" ->
      # SMTP Configuration (Google Workspace or Self-hosted)
      config :voile, Voile.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: System.get_env("VOILE_SMTP_RELAY") || "smtp.gmail.com",
        port: String.to_integer(System.get_env("VOILE_SMTP_PORT") || "587"),
        username: System.get_env("VOILE_SMTP_USERNAME"),
        password: System.get_env("VOILE_SMTP_PASSWORD"),
        ssl: System.get_env("VOILE_SMTP_SSL") == "true",
        tls: :if_available,
        auth: :always,
        # For Gmail/Google Workspace, use these settings:
        # relay: "smtp.gmail.com"
        # port: 587
        # tls: :if_available
        # auth: :always
        retries: 3,
        no_mx_lookups: false

    "mailgun" ->
      # Mailgun API Configuration
      config :voile, Voile.Mailer,
        adapter: Swoosh.Adapters.Mailgun,
        api_key: System.get_env("VOILE_MAILGUN_API_KEY"),
        domain: System.get_env("VOILE_MAILGUN_DOMAIN")

      config :swoosh, :api_client, Swoosh.ApiClient.Finch

    "sendgrid" ->
      # SendGrid API Configuration
      config :voile, Voile.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: System.get_env("VOILE_SENDGRID_API_KEY")

      config :swoosh, :api_client, Swoosh.ApiClient.Finch

    _ ->
      # Default to Local adapter (dev/test)
      config :voile, Voile.Mailer, adapter: Swoosh.Adapters.Local
  end

  # S3 Storage Configuration
  # Load S3 credentials from environment variables into application config
  if System.get_env("VOILE_S3_ACCESS_KEY_ID") do
    config :voile,
      storage_adapter: Client.Storage.S3,
      s3_access_key_id: System.get_env("VOILE_S3_ACCESS_KEY_ID"),
      s3_secret_key_access: System.get_env("VOILE_S3_SECRET_ACCESS_KEY"),
      s3_bucket_name: System.get_env("VOILE_S3_BUCKET_NAME") || "glam-storage",
      s3_region: System.get_env("VOILE_S3_REGION") || "us-east-1",
      s3_public_url: System.get_env("VOILE_S3_PUBLIC_URL") || "https://library.unpad.ac.id",
      s3_public_url_format:
        System.get_env("VOILE_S3_PUBLIC_URL_FORMAT") || "{endpoint}/{bucket}/{key}"
  else
    config :voile, storage_adapter: Client.Storage.Local
  end
end
