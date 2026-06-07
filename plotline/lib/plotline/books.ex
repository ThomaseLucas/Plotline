defmodule Plotline.Books do
  @moduledoc "Context for books being stored."
  alias Plotline.Repo
  alias Plotline.Books.Book
  alias Plotline.Extraction
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog

  def list_books, do: Repo.all(Book)

  def create_book(attrs) do
    %Book{}
    |> Book.changeset(attrs)
    |> Repo.insert()
  end

  def get_book!(id), do: Repo.get!(Book, id)

  @doc """
  Checks whether chapter-summaries.com has this title/author.
  """
  def chapter_summaries_available?(title, author) do
    Catalog.available?(title, author)
  end

  @doc """
  Looks up a book in the chapter-summaries.com catalog.

  Returns `{:ok, catalog_entry}` or `{:error, :not_in_catalog}`.
  """
  def lookup_chapter_summaries(title, author) do
    Catalog.find_book!(title, author)
  end

  @doc """
  Creates a book and imports all chapter summaries from chapter-summaries.com.

  The book must exist in the chapter-summaries.com catalog (matched by title + author).
  On success returns `{:ok, book, import_stats}`.

  ## Examples

      Books.add_book_with_summaries!(%{
        title: "Pride and Prejudice",
        author: "Jane Austen"
      })

  """
  def add_book_with_summaries!(attrs) when is_map(attrs) do
    title = Map.fetch!(attrs, :title)
    author = Map.fetch!(attrs, :author)

    with {:ok, entry} <- Catalog.find_book!(title, author),
         book_attrs <-
           attrs
           |> Map.put(:chapter_summaries_slug, entry.slug)
           |> Map.put_new(:total_chapters, entry.total_chapters),
         {:ok, book} <- create_book(book_attrs),
         {:ok, stats} <- Extraction.import_book(book.id, "chaptersummaries") do
      {:ok, book, stats}
    end
  end
end
