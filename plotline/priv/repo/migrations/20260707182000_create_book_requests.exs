defmodule Plotline.Repo.Migrations.CreateBookRequests do
  use Ecto.Migration

  def change do
    create table(:book_requests) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:author, :string, null: false)
      add(:notes, :text)
      add(:status, :string, null: false, default: "pending")

      timestamps(type: :utc_datetime)
    end

    create(index(:book_requests, [:user_id]))
    create(index(:book_requests, [:status]))
  end
end
