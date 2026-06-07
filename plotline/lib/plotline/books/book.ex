defmodule Plotline.Books.Book do
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:title, :author, :total_chapters, :hardcover_id, :cover_image_url, :chapter_summaries_slug]
  @required_fields [:title, :author]

  schema "books" do
    field(:title, :string)
    field(:author, :string)
    field(:total_chapters, :integer)
    field(:hardcover_id, :string)
    field(:cover_image_url, :string)
    field(:chapter_summaries_slug, :string)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates and casts data for creating/updating a book.
  """
  def changeset(book, attrs) do
    book
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:author, min: 1, max: 255)
    |> validate_number(:total_chapters, greater_than: 0)
    |> validate_length(:hardcover_id, max: 255)
    |> validate_format(:cover_image_url, ~r/^https?:\/\//,
      message: "must start with http:// or https://"
    )
    |> unique_constraint(:title, name: :books_title_author_index)
  end

  @doc """
  Limited fields for user/admin edits. (Prevents accidental mass-assignment)
  """
  def update_changeset(book, attrs) do
    book
    |> cast(attrs, [:title, :author, :total_chapters, :cover_image_url])
    |> validate_required([:title, :author])
    |> validate_number(:total_chapters, greater_than: 0)
  end

  @doc """
  Looser or different rules depending on data being ingested from different sources.
  Could be in different formatting or not get all the information the other changeset requires.
  """
  def import_changeset(book, attrs) do
    book
    |> cast(attrs, [:title, :author, :total_chapters, :hardcover_id, :cover_image_url, :chapter_summaries_slug])
    |> validate_required(:title)
    |> validate_number(:total_chapters, greater_than: 0)
    |> unique_constraint(:title, name: :books_title_author_index)
  end
end
