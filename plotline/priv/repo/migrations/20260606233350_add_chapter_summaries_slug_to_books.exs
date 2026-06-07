defmodule Plotline.Repo.Migrations.AddChapterSummariesSlugToBooks do
  use Ecto.Migration

  def change do
    alter table(:books) do
      add(:chapter_summaries_slug, :string)
    end

    create(index(:books, [:chapter_summaries_slug]))
  end
end
