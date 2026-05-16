defmodule Plotline.Repo.Migrations.CreateBooks do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:books) do
      add(:title, :string, null: false)
      add(:author, :string)
      add(:total_chapters, :integer)
      add(:hardcover_id, :string)
      add(:cover_image_url, :string)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:books, [:title, :author]))
  end
end
