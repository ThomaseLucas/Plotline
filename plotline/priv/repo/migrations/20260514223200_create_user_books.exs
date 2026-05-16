defmodule Plotline.Repo.Migrations.CreateUserBooks do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:user_books) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:book_id, references(:books, on_delete: :delete_all), null: false)
      add(:current_chapter_number, :integer, null: false, default: 0)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:user_books, [:user_id, :book_id]))
  end
end
