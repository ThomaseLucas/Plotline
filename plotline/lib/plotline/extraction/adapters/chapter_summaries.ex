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
    summary = extract_paragraphs(content, "summary-text")
    events = extract_list_items(content, "key-events")
    characters = extract_list_items(content, "characters-introduced")
    themes = extract_list_items(content, "chapter-themes")

    [
      summary,
      section_block("Key Events", events),
      section_block("Characters Introduced", characters),
      section_block("Themes", themes)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp section_block(_title, []), do: ""

  defp section_block(title, items) do
    bullets = Enum.map_join(items, "\n", &"- #{&1}")
    "## #{title}\n#{bullets}"
  end

  defp extract_paragraphs(content, class_name) do
    case extract_inner_html(content, class_name) do
      "" ->
        ""

      inner ->
        Regex.scan(~r/<p[^>]*>(.*?)<\/p>/s, inner, capture: :all_but_first)
        |> Enum.map(fn [p] -> clean_text(p) end)
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> clean_text(inner)
          paragraphs -> Enum.join(paragraphs, "\n\n")
        end
    end
  end

  defp extract_list_items(content, class_name) do
    case extract_inner_html(content, class_name) do
      "" ->
        []

      inner ->
        Regex.scan(~r/<li[^>]*>(.*?)<\/li>/s, inner, capture: :all_but_first)
        |> Enum.map(fn [item] -> clean_text(item) end)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp extract_inner_html(content, class_name) do
    # Match the opening div for this class, then take until the matching depth
    # closes. Nested lists don't use nested divs on chapter-summaries.com, so a
    # non-greedy div match is enough.
    case Regex.run(~r/<div class="#{class_name}"[^>]*>(.*?)<\/div>/s, content,
           capture: :all_but_first
         ) do
      [inner] -> inner
      _ -> ""
    end
  end

  defp clean_text(html) when is_binary(html) do
    html
    |> Http.strip_html()
    |> decode_entities()
    |> String.replace(~r/^[^A-Za-z0-9"']+/, "")
    |> String.trim()
  end

  defp decode_entities(text) do
    text
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&nbsp;", " ")
  end

  defp chapters_url(slug), do: "#{@base_url}/books/#{slug}/chapters/"
end
