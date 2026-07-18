defmodule Plotline.AI do
  @moduledoc """
  Spoiler-safe reading assistant built on imported chapter summaries.

  Configure with `GEMINI_API_KEY` in `.env` (see Google AI Studio).
  """

  alias Plotline.AI.Prompt
  alias Plotline.Summaries

  @doc "Returns true when an API key is configured."
  def enabled? do
    case api_key() do
      key when is_binary(key) and key != "" -> true
      _ -> false
    end
  end

  @doc """
  Answers a reader question using only summaries up to their current chapter.
  """
  def chat(user_book, message) when is_binary(message) do
    message = String.trim(message)

    with :ok <- ensure_enabled(),
         :ok <- ensure_progress(user_book),
         summaries <- load_summaries(user_book),
         {:ok, summaries} <- ensure_summaries(summaries),
         system_instruction <- Prompt.system_instruction(user_book, summaries),
         {:ok, reply} <- provider().generate(system_instruction, message) do
      {:ok, reply}
    end
  end

  @doc """
  Generates a spoiler-free chapter summary from raw chapter text.
  """
  def summarize_chapter(book_title, chapter) when is_map(chapter) do
    with :ok <- ensure_enabled(),
         system <- Prompt.chapter_summary_system(book_title),
         user_message <- Prompt.chapter_summary_user(chapter),
         {:ok, reply} <- provider().generate(system, user_message) do
      {:ok, reply}
    end
  end

  @doc """
  Summarizes several chapters in one model call.

  Returns `{:ok, [%{chapter_number: n, summary_text: text}, ...]}`.
  """
  def summarize_chapter_batch(book_title, chapters)
      when is_binary(book_title) and is_list(chapters) and chapters != [] do
    with :ok <- ensure_enabled(),
         system <- Prompt.chapter_batch_system(book_title),
         user_message <- Prompt.chapter_batch_user(chapters),
         {:ok, reply} <- provider().generate(system, user_message),
         {:ok, summaries} <- parse_batch_summaries(reply, chapters) do
      {:ok, summaries}
    end
  end

  defp parse_batch_summaries(reply, chapters) do
    expected = MapSet.new(Enum.map(chapters, & &1.number))

    with {:ok, decoded} <- decode_json_array(reply) do
      kept =
        decoded
        |> normalize_batch_items()
        |> Enum.filter(&MapSet.member?(expected, &1.chapter_number))
        |> Enum.uniq_by(& &1.chapter_number)

      if kept == [] do
        {:error, :invalid_batch_response}
      else
        {:ok, kept}
      end
    end
  end

  defp decode_json_array(reply) do
    cleaned =
      reply
      |> String.trim()
      |> String.replace(~r/^```(?:json)?\s*/i, "")
      |> String.replace(~r/\s*```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, list} when is_list(list) ->
        {:ok, list}

      {:ok, %{"summaries" => list}} when is_list(list) ->
        {:ok, list}

      {:ok, _} ->
        {:error, :invalid_batch_response}

      {:error, _} ->
        extract_json_array(cleaned)
    end
  end

  defp extract_json_array(text) do
    case Regex.run(~r/\[[\s\S]*\]/, text) do
      [json] ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) -> {:ok, list}
          _ -> {:error, :invalid_batch_response}
        end

      _ ->
        {:error, :invalid_batch_response}
    end
  end

  defp normalize_batch_items(items) do
    Enum.flat_map(items, fn
      %{"chapter_number" => n, "summary_text" => text}
      when is_integer(n) and is_binary(text) and text != "" ->
        [%{chapter_number: n, summary_text: String.trim(text)}]

      %{"chapter_number" => n, "summary_text" => text}
      when is_binary(n) and is_binary(text) and text != "" ->
        case Integer.parse(n) do
          {num, ""} -> [%{chapter_number: num, summary_text: String.trim(text)}]
          _ -> []
        end

      _ ->
        []
    end)
  end

  @doc """
  Generates a spoiler-safe recap of everything read so far.
  """
  def recap(user_book) do
    chat(user_book, Prompt.recap_message())
  end

  defp ensure_enabled do
    if enabled?(), do: :ok, else: {:error, :not_configured}
  end

  defp ensure_progress(%{current_chapter_number: chapter}) when chapter > 0, do: :ok
  defp ensure_progress(_), do: {:error, :no_progress}

  defp ensure_summaries([]), do: {:error, :no_summaries}
  defp ensure_summaries(summaries), do: {:ok, summaries}

  defp load_summaries(user_book) do
    Summaries.get_summaries_up_to(user_book.book_id, user_book.current_chapter_number)
  end

  defp provider do
    Application.get_env(:plotline, Plotline.AI, [])
    |> Keyword.get(:provider, Plotline.AI.Gemini)
  end

  defp api_key do
    Application.get_env(:plotline, Plotline.AI, [])
    |> Keyword.get(:api_key)
    |> case do
      key when is_binary(key) and key != "" -> key
      _ -> System.get_env("GEMINI_API_KEY")
    end
  end

  @doc false
  def humanize_error(:not_configured),
    do: "Reading assistant is not configured. Add GEMINI_API_KEY to your .env file."

  def humanize_error(:no_progress),
    do: "Set your current chapter above before using the reading assistant."

  def humanize_error(:no_summaries),
    do: "No chapter summaries are available for this book yet."

  def humanize_error(:rate_limited),
    do: "The AI service is rate-limited right now. Please wait a minute and try again."

  def humanize_error({:api_error, _status, message}) when is_binary(message), do: message

  def humanize_error(_reason),
    do: "Something went wrong talking to the reading assistant. Please try again."
end
