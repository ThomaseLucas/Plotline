import Config

# Load .env file (project root) into System env for tests, if present.
# This ensures local .env values are available when running `mix test`.
env_file = Path.expand("../.env", __DIR__)

if File.exists?(env_file) do
  env_file
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == "" || String.starts_with?(&1, "#")))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, val] ->
        val = String.trim(val, "\"' \t\r\n")
        System.put_env(key, val)

      _ ->
        :ok
    end
  end)
end

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :plotline, Plotline.Repo,
  username: System.get_env("PGUSER") || System.get_env("DB_USER") || "postgres",
  password: System.get_env("PGPASSWORD") || System.get_env("DB_PASS") || "postgres",
  hostname: System.get_env("PGHOST") || "localhost",
  database:
    System.get_env("PGDATABASE_TEST") || "plotline_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plotline, PlotlineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DJ62wt8pjAJvGtQqMXPumb/VytIgwR1SWjk39bLrk8bNfjmdaynccT9mdfvbFRdL",
  server: false

# In test we don't send emails
config :plotline, Plotline.Mailer, adapter: Swoosh.Adapters.Test

config :plotline, Plotline.CatalogSync, cooldown_ms: 0

config :plotline, Plotline.Extraction.Adapters.ChapterSummaries.Catalog,
  catalog_path: "test/support/fixtures/chapter_summaries/catalog.json"

config :plotline, Plotline.AI,
  api_key: "test-key",
  provider: Plotline.AI.TestProvider,
  request_retries: 0,
  retry_base_ms: 0

config :plotline, Plotline.Hardcover,
  api_token: "test-hardcover-token",
  client: Plotline.Hardcover.TestClient

config :plotline, Plotline.PdfUploads,
  upload_dir: "tmp/test_uploads/pdfs"

config :plotline, Plotline.PdfUploads.Processor,
  text_extractor: Plotline.Pdf.TextExtractor.TestExtractor,
  async: false,
  chapter_pause_ms: 0,
  batch_size: 4

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
