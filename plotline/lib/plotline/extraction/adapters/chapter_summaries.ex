defmodule Plotline.Extraction.Adapters.ChapterSummaries do
  @moduledoc """
  Extracts chapter summaries from chapter-summaries.com.

  Each book's summaries live on a single page:
  `https://chapter-summaries.com/books/{slug}/chapters/`

  The adapter fetches that page once, parses all `<section class="chapter-summary">`
  blocks, and caches them in memory for subsequent chapter lookups.
  """

  @behaviour Plotline.Extraction.Adapter

  alias Plotline.Books.Book
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog
  alias Plotline.Extraction.Adapters.Http

  @base_url "https://chapter-summaries.com"
  @chapters_cache_prefix {:plotline, :cs_chapters}

  @impl true
  def source_name, do: "ChapterSummaries.com"

  @impl true
  def fetch_chapter_summary(%Book{} = book, chapter_number) do
    with {:ok, slug} <- resolve_slug(book),
         {:ok, chapters} <- ensure_chapters_loaded(slug),
         {:ok, summary_text} <- Map.fetch(chapters, chapter_number) do
      {:ok,
       %{
         summary_text: summary_text,
         source_url: chapters_url(slug),
         scraped_at: DateTime.utc_now(:second)
       }}
    else
      :error -> {:error, :chapter_not_found}
      {:error, _} = error -> error
    end
  end

  @doc "Returns sorted chapter numbers available for a book on chapter-summaries.com."
  def list_chapters(%Book{} = book) do
    with {:ok, slug} <- resolve_slug(book),
         {:ok, chapters} <- ensure_chapters_loaded(slug) do
      chapters |> Map.keys() |> Enum.sort()
    else
      _ -> []
    end
  end

  @doc false
  def resolve_slug(%Book{chapter_summaries_slug: slug}) when is_binary(slug) and slug != "" do
    {:ok, slug}
  end

  def resolve_slug(%Book{title: title, author: author}) do
    case Catalog.find_book(title, author) do
      %{slug: slug} -> {:ok, slug}
      nil -> {:error, :not_in_catalog}
    end
  end

  @doc false
  def ensure_chapters_loaded(slug) when is_binary(slug) do
    cache_key = {@chapters_cache_prefix, slug}

    case :persistent_term.get(cache_key, nil) do
      {chapters, fetched_at} ->
        if System.monotonic_time(:millisecond) - fetched_at < :timer.hours(1) do
          {:ok, chapters}
        else
          fetch_and_cache(slug, cache_key)
        end

      _ ->
        fetch_and_cache(slug, cache_key)
    end
  end

  defp fetch_and_cache(slug, cache_key) do
    with {:ok, html} <- Http.fetch_html(chapters_url(slug)),
         {:ok, chapters} <- parse_chapters_page(html) do
      :persistent_term.put(cache_key, {chapters, System.monotonic_time(:millisecond)})
      {:ok, chapters}
    end
  end

  @doc false
  def parse_chapters_page(html) do
    sections =
      Regex.scan(
        ~r/<section class="chapter-summary" id="chapter-(\d+)"[^>]*>(.*?)<\/section>/s,
        html,
        capture: :all_but_first
      )

    if sections == [] do
      {:error, :no_chapters_found}
    else
      chapters =
        Map.new(sections, fn [number, content] ->
          {String.to_integer(number), extract_section_text(content)}
        end)

      {:ok, chapters}
    end
  end

  defp extract_section_text(content) do
    summary = extract_block(content, "summary-text")
    events = extract_block(content, "key-events")

    [summary, events]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp extract_block(content, class_name) do
    case Regex.run(~r/<div class="#{class_name}"[^>]*>(.*?)<\/div>/s, content,
           capture: :all_but_first
         ) do
      [inner] -> inner |> Http.strip_html() |> String.trim()
      _ -> ""
    end
  end

  defp chapters_url(slug), do: "#{@base_url}/books/#{slug}/chapters/"
end
