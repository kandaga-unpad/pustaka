# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :voile, :scopes,
  user: [
    default: true,
    module: Voile.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Voile.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :voile,
  ecto_repos: [Voile.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :voile, VoileWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: VoileWeb.ErrorHTML, json: VoileWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Voile.PubSub,
  live_view: [signing_salt: "q1X5qNFK"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :voile, Voile.Mailer, adapter: Swoosh.Adapters.Local

# Configure Upload Directory for Attachments
config :voile,
  attachment_upload_dir: "priv/static/uploads/attachments",
  # 100MB
  attachment_max_file_size: 100 * 1024 * 1024,
  attachment_allowed_file_types: [
    # Images
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/svg+xml",
    # Documents
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "text/plain",
    "text/csv",
    # Videos
    "video/mp4",
    "video/quicktime",
    "video/x-msvideo",
    # Audio
    "audio/mpeg",
    "audio/wav",
    "audio/ogg",
    # Archives
    "application/zip",
    "application/x-rar-compressed",
    "application/x-7z-compressed",
    # Software
    "application/octet-stream",
    "application/x-executable"
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  voile: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  voile: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Assent Configuration
config :assent, http_adapter: {Assent.HTTPAdapter.Finch, supervisor: Voile.Finch}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
