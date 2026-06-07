defmodule Plotline.Extraction.Adapters.ChapterSummaries.Catalog do
  @moduledoc """
  Tracks which books chapter-summaries.com has available.

  Fetches the paginated browse index, caches results locally in
  `priv/data/chapter_summaries_catalog.json`, and supports title/author lookup
  so the app can quickly tell if a requested book has summaries.
  """

  alias Plotline.Extraction.Adapters.Http

  @base_url "https://chapter-summaries.com"
  @catalog_path "priv/data/chapter_summaries_catalog.json"
  @cache_key {:plotline, :chapter_summaries_catalog}
  @ttl_ms :timer.hours(24)

  @type entry :: %{
          slug: String.t(),
          title: String.t(),
          author: String.t(),
          total_chapters: pos_integer(),
          url: String.t()
        }

  @doc "Returns all known books, using memory cache then disk then network."
  def list_books(opts \\ []) do
    force? = Keyword.get(opts, :force, false)

    cond do
      force? ->
        refresh!()

      cached = get_memory_cache() ->
        cached

      File.exists?(@catalog_path) ->
        load_disk!()
        get_memory_cache()

      true ->
        refresh!()
    end
  end

  @doc "Finds a catalog entry by exact normalized title and author."
  def find_book(title, author) when is_binary(title) and is_binary(author) do
    norm_title = normalize(title)
    norm_author = normalize(author)

    list_books()
    |> Enum.find(fn entry ->
      normalize(entry.title) == norm_title and normalize(entry.author) == norm_author
    end)
  end

  @doc "Returns `{:ok, entry}` or `{:error, :not_in_catalog}`."
  def find_book!(title, author) do
    case find_book(title, author) do
      nil -> {:error, :not_in_catalog}
      entry -> {:ok, entry}
    end
  end

  @doc "Returns true when chapter-summaries.com lists this title/author."
  def available?(title, author), do: find_book(title, author) != nil

  @doc """
  Fetches all browse pages and writes `priv/data/chapter_summaries_catalog.json`.
  Returns the book list.
  """
  def refresh! do
    books = fetch_all_pages()
    write_disk!(books)
    put_memory_cache(books)
    books
  end

  @doc "Loads catalog from disk into the memory cache."
  def load_disk! do
    books =
      @catalog_path
      |> File.read!()
      |> Jason.decode!()
      |> Enum.map(&atomize_entry/1)

    put_memory_cache(books)
    books
  end

  defp fetch_all_pages do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(&fetch_page/1)
    |> Stream.take_while(&(length(&1) > 0))
    |> Enum.flat_map(& &1)
    |> Enum.uniq_by(& &1.slug)
  end

  defp fetch_page(page) do
    url =
      if page == 1,
        do: "#{@base_url}/books/",
        else: "#{@base_url}/books/?page=#{page}"

    with {:ok, html} <- Http.fetch_html(url) do
      parse_browse_page(html)
    else
      _ -> []
    end
  end

  @doc false
  def parse_browse_page(html) do
    slugs =
      Regex.scan(~r/href="\/books\/([a-z0-9-]+)\/"/, html)
      |> Enum.map(fn [_, slug] -> slug end)
      |> Enum.uniq()

    titles =
      Regex.scan(~r/book-card-title"[^>]*>([^<]+)<\/h3>/, html)
      |> Enum.map(fn [_, title] -> decode_entities(title) end)

    authors =
      Regex.scan(~r/book-card-author"[^>]*>([^<]+)<\/p>/, html)
      |> Enum.map(fn [_, author] -> decode_entities(author) end)

    chapters =
      Regex.scan(~r/book-card-chapters">(\d+) chapters/, html)
      |> Enum.map(fn [_, count] -> String.to_integer(count) end)

    if length(slugs) == length(titles) and length(slugs) == length(authors) and
         length(slugs) == length(chapters) do
      Enum.zip([slugs, titles, authors, chapters])
      |> Enum.map(fn {slug, title, author, total_chapters} ->
        %{
          slug: slug,
          title: title,
          author: author,
          total_chapters: total_chapters,
          url: "#{@base_url}/books/#{slug}/"
        }
      end)
    else
      []
    end
  end

  @doc false
  def clear_cache! do
    :persistent_term.erase(@cache_key)
    :ok
  end

  defp write_disk!(books) do
    File.mkdir_p!(Path.dirname(@catalog_path))
    File.write!(@catalog_path, Jason.encode!(books, pretty: true))
  end

  defp get_memory_cache do
    case :persistent_term.get(@cache_key, nil) do
      {books, fetched_at} ->
        if System.monotonic_time(:millisecond) - fetched_at < @ttl_ms, do: books, else: nil

      _ ->
        nil
    end
  end

  defp put_memory_cache(books) do
    :persistent_term.put(@cache_key, {books, System.monotonic_time(:millisecond)})
    books
  end

  defp atomize_entry(map) do
    %{
      slug: map["slug"],
      title: map["title"],
      author: map["author"],
      total_chapters: map["total_chapters"],
      url: map["url"]
    }
  end

  defp normalize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, " ")
    |> String.trim()
  end

  defp decode_entities(text) do
    text
    |> String.replace("&#39;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end
end
