defmodule Plotline.Extraction.Adapters.JsonFile do
  @moduledoc """
  Loads manually curated chapter summaries from JSON files in `priv/data/extraction/`.

  File naming: slugified book title and author joined with `-` (lowercase, non-alphanumeric → `-`).

  Example file structure:

      {
        "source_name": "CuratedDemo",
        "chapters": {
          "1": {
            "summary_text": "Chapter one recap...",
            "source_url": "https://example.com/ch-1"
          }
        }
      }
  """

  @behaviour Plotline.Extraction.Adapter

  @data_dir "priv/data/extraction"

  @impl true
  def source_name, do: "CuratedDemo"

  @impl true
  def fetch_chapter_summary(book, chapter_number) do
    with {:ok, data} <- load_book_file(book),
         {:ok, chapter} <- Map.fetch(data["chapters"], Integer.to_string(chapter_number)) do
      {:ok,
       %{
         summary_text: chapter["summary_text"],
         source_url: chapter["source_url"],
         scraped_at: DateTime.utc_now(:second),
         source_name: data["source_name"] || source_name()
       }}
    else
      :error -> {:error, :chapter_not_found}
      {:error, _} = error -> error
    end
  end

  @doc "Returns all chapter numbers available in the JSON file for a book."
  def list_chapters(book) do
    with {:ok, data} <- load_book_file(book) do
      data["chapters"]
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.sort()
    else
      _ -> []
    end
  end

  defp load_book_file(book) do
    path = Path.join([@data_dir, slugify(book.title, book.author) <> ".json"])

    case File.read(path) do
      {:ok, contents} ->
        case Jason.decode(contents) do
          {:ok, data} when is_map(data) -> {:ok, data}
          _ -> {:error, :invalid_json}
        end

      {:error, :enoent} ->
        {:error, {:file_not_found, path}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp slugify(title, author) do
    [title, author]
    |> Enum.join("-")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
