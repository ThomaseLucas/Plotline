defmodule Plotline.Books do
  @moduledoc "Context for books being stored."

  import Ecto.Query, warn: false

  alias Plotline.Repo
  alias Plotline.Books.Book
  alias Plotline.Extraction
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog
  alias Plotline.Summaries.ChapterSummary
  alias Plotline.UserBooks

  def list_books, do: Repo.all(Book)

  def create_book(attrs) do
    %Book{}
    |> Book.changeset(attrs)
    |> Repo.insert()
  end

  def get_book!(id), do: Repo.get!(Book, id)

  def get_book_by_title_author(title, author) do
    Repo.get_by(Book, title: title, author: author)
  end

  @doc """
  Searches the local chapter-summaries.com catalog by title or author substring.
  """
  def search_catalog(query) when is_binary(query) do
    q = String.downcase(String.trim(query))

    if q == "" do
      Catalog.list_books()
    else
      Catalog.list_books()
      |> Enum.filter(fn entry ->
        String.contains?(String.downcase(entry.title), q) or
          String.contains?(String.downcase(entry.author), q)
      end)
    end
  end

  @doc """
  Returns how many books are in the local chapter-summaries.com catalog cache.
  """
  def catalog_size, do: Catalog.list_books() |> length()

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
  Adds a catalog book to a user's library: creates or reuses the book record,
  imports summaries if needed, and creates a `user_books` row.

  Returns `{:ok, user_book, book}` or an error tuple.
  """
  def add_to_user_library(user_id, title, author) do
    with {:ok, entry} <- Catalog.find_book!(title, author),
         {:ok, book} <- get_or_import_book(entry),
         :ok <- ensure_not_in_library(user_id, book.id),
         {:ok, user_book} <-
           UserBooks.create_user_book(user_id, book.id, %{current_chapter_number: 0}) do
      {:ok, user_book, book}
    end
  end

  @doc """
  Creates a book and imports all chapter summaries from chapter-summaries.com.

  The book must exist in the chapter-summaries.com catalog (matched by title + author).
  On success returns `{:ok, book, import_stats}`.
  """
  def add_book_with_summaries!(attrs) when is_map(attrs) do
    title = Map.fetch!(attrs, :title)
    author = Map.fetch!(attrs, :author)

    with {:ok, entry} <- Catalog.find_book!(title, author),
         book_attrs <-
           attrs
           |> Map.put(:chapter_summaries_slug, entry.slug)
           |> Map.put_new(:total_chapters, entry.total_chapters)
           |> Map.put_new(:cover_image_url, Catalog.cover_image_url(entry)),
         {:ok, book} <- create_book(book_attrs),
         {:ok, stats} <- Extraction.import_book(book.id, "chaptersummaries") do
      {:ok, book, stats}
    end
  end

  defp get_or_import_book(entry) do
    case get_book_by_title_author(entry.title, entry.author) do
      %Book{} = book ->
        if summaries_imported?(book.id) do
          {:ok, book}
        else
          import_summaries_for(book)
        end

      nil ->
        add_book_with_summaries!(%{
          title: entry.title,
          author: entry.author,
          total_chapters: entry.total_chapters,
          chapter_summaries_slug: entry.slug,
          cover_image_url: Catalog.cover_image_url(entry)
        })
        |> case do
          {:ok, book, _stats} -> {:ok, book}
          error -> error
        end
    end
  end

  defp summaries_imported?(book_id) do
    from(cs in ChapterSummary, where: cs.book_id == ^book_id, select: 1, limit: 1)
    |> Repo.one()
    |> then(&(!is_nil(&1)))
  end

  defp import_summaries_for(book) do
    case Extraction.import_book(book.id, "chaptersummaries") do
      {:ok, _stats} -> {:ok, book}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_not_in_library(user_id, book_id) do
    if UserBooks.get_user_book(user_id, book_id) do
      {:error, :already_in_library}
    else
      :ok
    end
  end
end
