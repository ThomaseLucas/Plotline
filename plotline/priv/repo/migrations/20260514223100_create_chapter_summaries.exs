defmodule Plotline.Repo.Migrations.CreateChapterSummaries do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:chapter_summaries) do
      add(:book_id, references(:books, on_delete: :delete_all), null: false)
      add(:chapter_number, :integer, null: false)
      add(:summary_text, :text, null: false)
      add(:source_name, :string, null: false)
      add(:source_url, :string)
      add(:scraped_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:chapter_summaries, [:book_id, :chapter_number, :source_name]))
    create(index(:chapter_summaries, [:book_id, :chapter_number]))
  end
end
