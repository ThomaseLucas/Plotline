defmodule Plotline.Summaries do
  @moduledoc "Context for chapter summaries"

  import Ecto.Query, warn: false
  alias Plotline.Repo
  alias Plotline.Summaries.ChapterSummary

  def create_summary(attrs) do
    %ChapterSummary{}
    |> ChapterSummary.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_summary(attrs) do
    now = DateTime.utc_now(:second)

    %ChapterSummary{}
    |> ChapterSummary.changeset(Map.put_new(attrs, :scraped_at, now))
    |> Repo.insert(
      on_conflict: {:replace, [:summary_text, :source_url, :scraped_at, :updated_at]},
      conflict_target: [:book_id, :chapter_number, :source_name],
      returning: true
    )
  end

  def get_summaries_up_to(book_id, chapter_number) do
    from(cs in ChapterSummary,
      where: cs.book_id == ^book_id and cs.chapter_number <= ^chapter_number,
      order_by: [asc: cs.chapter_number]
    )
    |> Repo.all()
  end

  def has_summary?(book_id, chapter_number, source_name)
      when is_integer(book_id) and is_integer(chapter_number) and is_binary(source_name) do
    from(cs in ChapterSummary,
      where:
        cs.book_id == ^book_id and cs.chapter_number == ^chapter_number and
          cs.source_name == ^source_name,
      select: 1,
      limit: 1
    )
    |> Repo.one()
    |> then(&(not is_nil(&1)))
  end
end
