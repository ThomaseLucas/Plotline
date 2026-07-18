defmodule Plotline.Summaries.Format do
  @moduledoc false

  @doc """
  Turns stored summary text into renderable sections.

  Supports the structured scrape format (`## Key Events` + `- bullets`) and
  best-effort cleanup of older mashed-together text.
  """
  def to_sections(text) when is_binary(text) do
    text
    |> normalize_newlines()
    |> String.trim()
    |> normalize_assistant_markdown()
    |> normalize_legacy()
    |> parse_structured()
  end

  def to_sections(_), do: []

  defp normalize_newlines(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
  end

  # Convert common Gemini markdown into Plotline ## / - structure.
  defp normalize_assistant_markdown(text) do
    text
    |> String.replace(~r/^\*\s+/m, "- ")
    |> String.split("\n")
    |> Enum.flat_map(&normalize_markdown_line/1)
    |> Enum.join("\n")
    |> String.replace(~r/\*\*([^*]+)\*\*/, "\\1")
  end

  defp normalize_markdown_line(line) do
    cond do
      match = Regex.run(~r/^-\s+\*\*(.+?)\*\*\s*:?\s*(.*)$/u, line) ->
        [_, title, rest] = match
        title = String.trim(title) |> String.trim_trailing(":")
        rest = String.trim(rest)

        if rest == "" do
          ["", "## #{title}"]
        else
          ["", "## #{title}", "", rest]
        end

      match = Regex.run(~r/^(#+)\s+(.+)$/u, line) ->
        [_, _hashes, title] = match
        ["", "## #{String.trim(title)}"]

      true ->
        [line]
    end
  end

  defp normalize_legacy(text) do
    cond do
      String.contains?(text, "## Key Events") or String.contains?(text, "\n- ") ->
        text

      String.contains?(text, "Key Events") ->
        case String.split(text, "Key Events", parts: 2) do
          [summary, events] ->
            summary =
              summary
              # Drop garble stuck after the last sentence (e.g. "cccccc").
              |> String.replace(~r/([.!?])\s*[A-Za-z]+$/u, "\\1")
              |> String.trim()

            bullets =
              events
              |> String.trim()
              |> String.split(~r/(?<=\.)\s+/)
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
              |> Enum.map_join("\n", &"- #{&1}")

            [summary, "## Key Events", bullets]
            |> Enum.reject(&(&1 == ""))
            |> Enum.join("\n\n")

          _ ->
            text
        end

      true ->
        text
    end
  end

  defp parse_structured(text) do
    text
    |> String.split(~r/\n(?=## )/u)
    |> Enum.flat_map(&parse_block/1)
  end

  defp parse_block(<<"## ", rest::binary>>) do
    case String.split(rest, "\n", parts: 2) do
      [title, body] -> List.wrap(heading_section(title, body))
      [title] -> List.wrap(heading_section(title, ""))
    end
  end

  defp parse_block(prose), do: List.wrap(prose_section(nil, prose))

  defp prose_section(title, text) do
    paragraphs =
      text
      |> String.split(~r/\n{2,}/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reject(&String.starts_with?(&1, "- "))
      |> Enum.reject(&String.starts_with?(&1, "## "))

    if paragraphs == [] do
      nil
    else
      %{title: title, paragraphs: paragraphs, items: []}
    end
  end

  defp heading_section(title, body) do
    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    items =
      lines
      |> Enum.filter(&String.starts_with?(&1, "- "))
      |> Enum.map(fn
        <<"- ", rest::binary>> -> String.trim(rest)
        line -> line
      end)

    paragraphs =
      lines
      |> Enum.reject(&String.starts_with?(&1, "- "))
      |> Enum.reject(&(&1 == ""))

    if items == [] and paragraphs == [] do
      nil
    else
      %{title: String.trim(title), paragraphs: paragraphs, items: items}
    end
  end
end
