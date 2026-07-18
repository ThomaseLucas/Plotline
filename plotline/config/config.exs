# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :plotline, :scopes,
  user: [
    default: true,
    module: Plotline.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Plotline.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :plotline,
  ecto_repos: [Plotline.Repo],
  generators: [timestamp_type: :utc_datetime]

config :plotline, Plotline.CatalogSync, cooldown_ms: :timer.seconds(30)

config :plotline, Plotline.AI,
  provider: Plotline.AI.Gemini,
  model: "gemini-flash-lite-latest",
  api_key: nil,
  request_retries: 3,
  retry_base_ms: 20_000

config :plotline, Plotline.Hardcover, api_token: nil

config :plotline, Plotline.PdfUploads, upload_dir: "priv/uploads/pdfs"

config :plotline, Plotline.PdfUploads.Processor,
  chapter_pause_ms: 2_000,
  batch_size: 4

# Configure the endpoint
config :plotline, PlotlineWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PlotlineWeb.ErrorHTML, json: PlotlineWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Plotline.PubSub,
  live_view: [signing_salt: "OqSSXj6i"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :plotline, Plotline.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  plotline: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  plotline: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
