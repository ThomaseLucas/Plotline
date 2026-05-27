defmodule Plotline.Summaries.ChapterSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:book_id, :chapter_number, :summary_text, :source_name, :source_url, :scraped_at]
  @required [:book_id, :chapter_number, :summary_text, :source_name]

  schema "chapter_summaries" do
    field(:chapter_number, :integer)
    field(:summary_text, :string)
    field(:source_name, :string)
    field(:source_url, :string)
    field(:scraped_at, :utc_datetime)

    belongs_to(:book, Plotline.Books.Book)

    timestamps(type: :utc_datetime)
  end

  def changeset(summary, attrs) do
    summary
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> validate_number(:chapter_number, greater_than: 0)
    |> unique_constraint(:source_name,
      name: :chapter_summaries_book_id_chapter_number_source_name_index
    )
  end
end
