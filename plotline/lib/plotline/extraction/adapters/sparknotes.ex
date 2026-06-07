defmodule Plotline.Extraction.Adapters.Sparknotes do
  @moduledoc """
  Extracts chapter summaries from SparkNotes literature guide pages.

  Expects `book.sparknotes_slug` metadata stored on the book record via
  `hardcover_id` prefix `sparknotes:` or a matching title in the demo map below.

  For the MVP demo, only books with known SparkNotes slugs are supported.
  """

  @behaviour Plotline.Extraction.Adapter

  alias Plotline.Extraction.Adapters.Http

  @demo_slugs %{
    "pride and prejudice" => "pride-and-prejudice"
  }

  @impl true
  def source_name, do: "Sparknotes"

  @impl true
  def fetch_chapter_summary(book, chapter_number) do
    with {:ok, slug} <- resolve_slug(book),
         url <- chapter_url(slug, chapter_number),
         {:ok, html} <- Http.fetch_html(url),
         {:ok, text} <- extract_summary(html) do
      {:ok,
       %{
         summary_text: text,
         source_url: url,
         scraped_at: DateTime.utc_now(:second)
       }}
    end
  end

  defp resolve_slug(book) do
    cond do
      is_binary(book.hardcover_id) and String.starts_with?(book.hardcover_id, "sparknotes:") ->
        {:ok, String.replace_prefix(book.hardcover_id, "sparknotes:", "")}

      slug = Map.get(@demo_slugs, String.downcase(book.title)) ->
        {:ok, slug}

      true ->
        {:error, :sparknotes_slug_not_configured}
    end
  end

  defp chapter_url(slug, chapter_number) do
    "https://www.sparknotes.com/lit/#{slug}/section#{chapter_number}/"
  end

  defp extract_summary(html) do
    case Regex.run(~r/<div[^>]*class="[^"]*summary[^"]*"[^>]*>(.*?)<\/div>/s, html, capture: :all_but_first) do
      [content | _] ->
        text = Http.strip_html(content)

        if String.length(text) > 50 do
          {:ok, text}
        else
          {:error, :summary_too_short}
        end

      _ ->
        {:error, :summary_not_found}
    end
  end
end
