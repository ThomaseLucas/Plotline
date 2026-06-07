defmodule Plotline.Extraction do
  @moduledoc """
  Orchestrates chapter summary extraction from external sources and storage.

  Adapters implement `Plotline.Extraction.Adapter`. Use `extract_chapter/3` for
  a single chapter or `import_book/2` to load all available chapters for a book.
  """

  alias Plotline.Books
  alias Plotline.Books.Book
  alias Plotline.Summaries

  @adapters %{
    "json" => Plotline.Extraction.Adapters.JsonFile,
    "sparknotes" => Plotline.Extraction.Adapters.Sparknotes,
    "chaptersummaries" => Plotline.Extraction.Adapters.ChapterSummaries
  }

  @doc "Lists registered adapter keys (e.g. `\"json\"`, `\"sparknotes\"`)."
  def list_adapters, do: Map.keys(@adapters)

  @doc "Returns the adapter module for a given key, or `nil`."
  def get_adapter(key) when is_binary(key), do: Map.get(@adapters, key)

  @doc """
  Fetches one chapter from the adapter and upserts it into `chapter_summaries`.
  """
  def extract_chapter(book_id, chapter_number, adapter_key)
      when is_integer(book_id) and is_integer(chapter_number) and is_binary(adapter_key) do
    with %Book{} = book <- Books.get_book!(book_id),
         adapter when not is_nil(adapter) <- get_adapter(adapter_key),
         {:ok, attrs} <- adapter.fetch_chapter_summary(book, chapter_number) do
      source_name = Map.get(attrs, :source_name, adapter.source_name())

      Summaries.upsert_summary(
        attrs
        |> Map.drop([:source_name])
        |> Map.merge(%{
          book_id: book.id,
          chapter_number: chapter_number,
          source_name: source_name
        })
      )
    else
      nil -> {:error, :unknown_adapter}
      {:error, _} = error -> error
    end
  end

  @doc """
  Imports all chapters listed by the JSON file adapter, or a numeric range for HTTP adapters.

  Options:
    * `:chapters` – explicit list of chapter numbers
    * `:from` / `:to` – inclusive chapter range
  """
  def import_book(book_id, adapter_key, opts \\ []) do
    adapter = get_adapter(adapter_key)

    with %Book{} = book when not is_nil(adapter) <- Books.get_book!(book_id),
         chapters <- resolve_chapters(book, adapter, opts) do
      results =
        Enum.map(chapters, fn chapter_number ->
          {chapter_number, extract_chapter(book.id, chapter_number, adapter_key)}
        end)

      ok_count = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
      errors = Enum.filter(results, fn {_, result} -> match?({:error, _}, result) end)

      {:ok, %{imported: ok_count, total: length(chapters), errors: errors}}
    else
      nil -> {:error, :unknown_adapter}
    end
  end

  defp resolve_chapters(book, adapter, opts) do
    cond do
      chapters = Keyword.get(opts, :chapters) ->
        chapters

      adapter == Plotline.Extraction.Adapters.JsonFile ->
        Plotline.Extraction.Adapters.JsonFile.list_chapters(book)

      adapter == Plotline.Extraction.Adapters.ChapterSummaries ->
        Plotline.Extraction.Adapters.ChapterSummaries.list_chapters(book)

      Keyword.has_key?(opts, :from) ->
        from = Keyword.fetch!(opts, :from)
        to = Keyword.get(opts, :to, from)
        Enum.to_list(from..to)

      true ->
        []
    end
  end
end
