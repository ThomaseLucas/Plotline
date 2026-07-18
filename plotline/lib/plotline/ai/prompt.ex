defmodule Plotline.AI.Prompt do
  @moduledoc false

  @recap_message "Give me a concise recap of everything I've read so far. Use short paragraphs and mention the most important characters and plot beats."

  @max_context_chars 400_000

  def recap_message, do: @recap_message

  def system_instruction(user_book, summaries) do
    book = user_book.book
    chapter = user_book.current_chapter_number

    """
    You are Plotline, a spoiler-safe reading assistant for "#{book.title}" by #{book.author}.

    The reader's current chapter is #{chapter}. You may ONLY use the chapter summaries below (chapters 1 through #{chapter}).

    Rules:
    - Never describe events, twists, character fates, or relationships from chapters after #{chapter}.
    - If asked about unread material, say the reader has not reached that part yet.
    - If the summaries do not contain enough information, say so instead of inventing plot details.

    Formatting (required):
    - Use plain text suitable for a reading app. Do NOT use Markdown bold (**), italics, or numbered callouts.
    - Start with 1–3 short prose paragraphs.
    - For distinct topics or people, use ## Heading lines (example: ## Relationship with Darrow).
    - Under each heading, use short paragraphs and/or simple "- " bullet lines.
    - Prefer readable prose over dense bullet dumps.
    - For recaps, organize by major plot beats with ## headings rather than listing every chapter.

    Chapter summaries:
    #{format_summaries(summaries)}
    """
    |> String.trim()
  end

  def chapter_summary_system(book_title) when is_binary(book_title) do
    """
    You write concise, spoiler-contained chapter summaries for Plotline.

    Book: #{book_title}

    Rules:
    - Summarize ONLY the chapter text provided. Do not invent plot from outside knowledge.
    - Do not spoil later chapters.
    - Output format exactly:

    <2-4 short paragraphs of prose summary>

    ## Key Events
    - bullet
    - bullet

    ## Characters
    - Name — brief role in this chapter

    ## Themes
    - theme
    """
    |> String.trim()
  end

  def chapter_summary_user(%{number: number, title: title, text: text}) do
    clipped = text |> String.trim() |> String.slice(0, 24_000)

    """
    Summarize chapter #{number} (#{title}).

    Chapter text:
    #{clipped}
    """
    |> String.trim()
  end

  def chapter_batch_system(book_title) when is_binary(book_title) do
    """
    You write concise chapter summaries for Plotline for "#{book_title}".

    Rules:
    - Summarize ONLY the chapter texts provided. Do not invent plot from outside knowledge.
    - Keep each chapter self-contained; do not spoil later chapters in earlier summaries.
    - Respond with JSON only (no markdown fences). An array of objects with keys:
      "chapter_number" (integer) and "summary_text" (string).
    - Each summary_text should use this shape:

    <2-4 short paragraphs>

    ## Key Events
    - bullet

    ## Characters
    - Name — brief role

    ## Themes
    - theme
    """
    |> String.trim()
  end

  def chapter_batch_user(chapters) when is_list(chapters) do
    body =
      Enum.map_join(chapters, "\n\n", fn %{number: number, title: title, text: text} ->
        clipped = text |> String.trim() |> String.slice(0, 8_000)

        """
        ===== CHAPTER #{number}: #{title} =====
        #{clipped}
        """
        |> String.trim()
      end)

    """
    Summarize each chapter below. Return one JSON array covering every chapter number provided.

    #{body}
    """
    |> String.trim()
  end

  defp format_summaries(summaries) do
    summaries
    |> Enum.map_join("\n\n", fn summary ->
      """
      --- Chapter #{summary.chapter_number} ---
      #{String.trim(summary.summary_text)}
      """
      |> String.trim()
    end)
    |> truncate_context()
  end

  defp truncate_context(text) when byte_size(text) <= @max_context_chars, do: text

  defp truncate_context(text) do
    trimmed = String.slice(text, -@max_context_chars, @max_context_chars)

    "[Note: earlier chapters were trimmed to fit context limits.]\n\n" <> trimmed
  end
end
