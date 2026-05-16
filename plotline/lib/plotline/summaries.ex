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

  def get_summaries_up_to(book_id, chapter_number) do
    from(cs in ChapterSummary,
      where: cs.book_id == ^book_id and cs.chapter_number <= ^chapter_number,
      order_by: [asc: cs.chapter_number]
    )
    |> Repo.all()
  end
end
