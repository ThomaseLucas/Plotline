defmodule Plotline.Pdf.ChapterSplitter do
  @moduledoc """
  Splits extracted PDF text into chapters using common heading patterns.

  If no headings are found, falls back to equal-sized chunks so summarization
  can still run for the demo.
  """

  @fallback_chunk_count 10
  @min_chapter_chars 80

  @heading_regex ~r/(?m)^[ \t]*(?:CHAPTER|Chapter|LETTER|Letter|PART|Part)[ \t]+([IVXLCDM]+|\d+)(?:[ \t]*[\.:\-–—]?[ \t]*(.*))?$/u

  @doc """
  Splits `text` into a list of maps:

      %{number: pos_integer(), title: String.t(), text: String.t()}
  """
  def split(text) when is_binary(text) do
    text = String.trim(text)

    case split_by_headings(text) do
      [] -> fallback_chunks(text)
      chapters -> chapters
    end
  end

  @doc """
  Best-effort title guess from the start of the document, falling back to
  `fallback_title` (typically derived from the filename).
  """
  def guess_title(text, fallback_title) when is_binary(text) and is_binary(fallback_title) do
    front = text |> String.slice(0, 2_000) |> String.split("\n") |> Enum.map(&String.trim/1)

    candidate =
      Enum.find_value(front, fn line ->
        cond do
          line == "" -> nil
          String.length(line) > 80 -> nil
          String.match?(line, ~r/^(project gutenberg|produced by|transcribed)/i) -> nil
          String.match?(line, @heading_regex) -> nil
          String.match?(line, ~r/^[A-Za-z0-9][A-Za-z0-9'’:\- ,.&]{2,79}$/) -> line
          true -> nil
        end
      end)

    case candidate do
      nil -> fallback_title
      title -> title
    end
  end

  defp split_by_headings(text) do
    matches = Regex.scan(@heading_regex, text, return: :index)

    case matches do
      [] ->
        []

      [_ | _] = all ->
        indices =
          Enum.map(all, fn
            [{start, len} | _] -> {start, start + len}
          end)

        Enum.with_index(indices, 1)
        |> Enum.map(fn {{start, heading_end}, index} ->
          next_start =
            case Enum.at(indices, index) do
              {ns, _} -> ns
              nil -> byte_size(text)
            end

          heading = binary_part(text, start, heading_end - start) |> String.trim()
          body = binary_part(text, heading_end, next_start - heading_end) |> String.trim()

          %{
            number: index,
            title: heading_title(heading, index),
            text: body
          }
        end)
        |> Enum.reject(fn %{text: body} -> String.length(body) < @min_chapter_chars end)
        |> renumber()
    end
  end

  defp heading_title(heading, index) do
    case Regex.run(@heading_regex, heading) do
      [_, num, rest] when is_binary(rest) and rest != "" ->
        "Chapter #{normalize_number(num)}: #{String.trim(rest)}"

      [_, num | _] ->
        "Chapter #{normalize_number(num)}"

      _ ->
        "Chapter #{index}"
    end
  end

  defp normalize_number(num) do
    case Integer.parse(num) do
      {n, ""} -> n
      _ -> roman_to_int(String.upcase(num)) || num
    end
  end

  defp roman_to_int(roman) do
    values = %{"I" => 1, "V" => 5, "X" => 10, "L" => 50, "C" => 100, "D" => 500, "M" => 1000}

    list =
      roman
      |> String.graphemes()
      |> Enum.map(&Map.get(values, &1))

    if Enum.any?(list, &is_nil/1) do
      nil
    else
      list
      |> Enum.chunk_every(2, 1, [0])
      |> Enum.reduce(0, fn
        [a, b], acc when a < b -> acc - a
        [a, _b], acc -> acc + a
      end)
    end
  end

  defp fallback_chunks(text) when byte_size(text) == 0, do: []

  defp fallback_chunks(text) do
    length = String.length(text)
    chunk_count = min(@fallback_chunk_count, max(1, div(length, 1_500)))
    chunk_size = max(1, div(length, chunk_count))

    1..chunk_count
    |> Enum.map(fn n ->
      start = (n - 1) * chunk_size
      take = if n == chunk_count, do: length - start, else: chunk_size
      body = String.slice(text, start, take) |> String.trim()

      %{number: n, title: "Section #{n}", text: body}
    end)
    |> Enum.reject(fn %{text: body} -> body == "" end)
  end

  defp renumber(chapters) do
    chapters
    |> Enum.with_index(1)
    |> Enum.map(fn {chapter, n} -> Map.put(chapter, :number, n) end)
  end
end
