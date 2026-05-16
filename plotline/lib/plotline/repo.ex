defmodule Plotline.Repo do
  use Ecto.Repo,
    otp_app: :plotline,
    adapter: Ecto.Adapters.Postgres
end
