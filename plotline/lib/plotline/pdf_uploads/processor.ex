defmodule Plotline.PdfUploads.Processor do
  @moduledoc """
  Turns an uploaded PDF into a library book with AI chapter summaries.

  Pipeline: extract text → split chapters → Hardcover metadata → create book /
  user_book → Gemini per-chapter summaries → mark upload ready.
  """

  require Logger

  alias Plotline.AI
  alias Plotline.Books
  alias Plotline.Books.Book
  alias Plotline.Hardcover
  alias Plotline.Pdf.ChapterSplitter
  alias Plotline.PdfUploads
  alias Plotline.PdfUploads.PdfUpload
  alias Plotline.Repo
  alias Plotline.Summaries
  alias Plotline.UserBooks

  @max_chapters 40

  @doc """
  Processes a PDF upload by id. Safe to call from a background Task.
  """
  def process(upload_id) when is_integer(upload_id) do
    upload = PdfUploads.get_upload!(upload_id)
    process_upload(upload)
  end

  def process(%PdfUpload{} = upload), do: process_upload(upload)

  defp process_upload(%PdfUpload{status: "ready", book_id: book_id} = upload)
       when not is_nil(book_id) do
    {:ok, upload}
  end

  defp process_upload(%PdfUpload{} = upload) do
    with {:ok, upload} <- PdfUploads.update_upload(upload, %{status: "processing"}),
         path <- PdfUploads.absolute_path(upload),
         {:ok, text} <- extract_text(path),
         chapters <- ChapterSplitter.split(text) |> Enum.take(@max_chapters),
         {:ok, chapters} <- ensure_chapters(chapters),
         fallback_title <- PdfUploads.display_title(upload),
         title_guess <- ChapterSplitter.guess_title(text, fallback_title),
         metadata <- enrich_metadata(title_guess),
         {:ok, book} <- get_or_create_book(metadata, length(chapters)),
         {:ok, _user_book} <- ensure_user_book(upload.user_id, book.id),
         :ok <- summarize_chapters(book, chapters),
         {:ok, upload} <-
           PdfUploads.update_upload(upload, %{status: "ready", book_id: book.id}) do
      {:ok, upload}
    else
      {:error, reason} = error ->
        _ = maybe_mark_failed(upload_id(upload), reason)
        Logger.warning("PDF process failed for upload #{upload_id(upload)}: #{inspect(reason)}")
        error
    end
  end

  defp upload_id(%PdfUpload{id: id}), do: id
  defp upload_id(id) when is_integer(id), do: id

  defp maybe_mark_failed(id, _reason) do
    case PdfUploads.get_upload!(id) do
      %PdfUpload{status: "ready"} = upload ->
        {:ok, upload}

      upload ->
        PdfUploads.update_upload(upload, %{status: "failed"})
    end
  rescue
    _ -> :ok
  end

  defp extract_text(path) do
    text_extractor().extract(path)
  end

  defp text_extractor do
    Application.get_env(:plotline, __MODULE__, [])
    |> Keyword.get(:text_extractor, Plotline.Pdf.TextExtractor)
  end

  defp ensure_chapters([]), do: {:error, :no_chapters}
  defp ensure_chapters(chapters), do: {:ok, chapters}

  defp enrich_metadata(title_guess) do
    case Hardcover.best_match(title_guess) do
      %{title: title} = hit ->
        %{
          title: title,
          author: hit.author || "Unknown",
          hardcover_id: hit.hardcover_id,
          cover_image_url: valid_cover(hit.cover_image_url)
        }

      nil ->
        %{
          title: title_guess,
          author: "Unknown",
          hardcover_id: nil,
          cover_image_url: nil
        }
    end
  end

  defp valid_cover(url) when is_binary(url) do
    if String.match?(url, ~r/^https?:\/\//i), do: url, else: nil
  end

  defp valid_cover(_), do: nil

  defp get_or_create_book(metadata, total_chapters) do
    attrs =
      metadata
      |> Map.put(:total_chapters, total_chapters)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Books.get_book_by_title_author(attrs.title, attrs.author) do
      %Book{} = book ->
        maybe_update_total_chapters(book, total_chapters)

      nil ->
        Books.create_book(attrs)
    end
  end

  defp maybe_update_total_chapters(book, total_chapters) do
    if is_nil(book.total_chapters) or book.total_chapters < total_chapters do
      book
      |> Book.changeset(%{total_chapters: total_chapters})
      |> Repo.update()
    else
      {:ok, book}
    end
  end

  defp ensure_user_book(user_id, book_id) do
    case UserBooks.get_user_book(user_id, book_id) do
      nil -> UserBooks.create_user_book(user_id, book_id, %{current_chapter_number: 0})
      user_book -> {:ok, user_book}
    end
  end

  defp summarize_chapters(book, chapters) do
    batch_size = Keyword.get(processor_config(), :batch_size, 4)
    pause_ms = Keyword.get(processor_config(), :chapter_pause_ms, 2_000)

    pending =
      Enum.reject(chapters, fn chapter ->
        Summaries.has_summary?(book.id, chapter.number, "pdf_ai")
      end)

    pending
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      summarize_batch(book, batch, pause_ms)
    end)
  end

  defp summarize_batch(book, batch, pause_ms) do
    case AI.summarize_chapter_batch(book.title, batch) do
      {:ok, summaries} ->
        case persist_batch_summaries(book.id, summaries) do
          :ok ->
            if pause_ms > 0, do: Process.sleep(pause_ms)
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp persist_batch_summaries(book_id, summaries) do
    Enum.reduce_while(summaries, :ok, fn %{chapter_number: n, summary_text: text}, :ok ->
      case Summaries.upsert_summary(%{
             book_id: book_id,
             chapter_number: n,
             summary_text: text,
             source_name: "pdf_ai",
             source_url: nil
           }) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp processor_config do
    Application.get_env(:plotline, __MODULE__, [])
  end

  @doc false
  def humanize_error(:pdftotext_missing),
    do: "PDF text extraction requires pdftotext (Poppler) on PATH."

  def humanize_error(:empty_text),
    do: "Could not extract text from this PDF (it may be image-only)."

  def humanize_error(:file_not_found), do: "Uploaded PDF file was not found on disk."
  def humanize_error(:no_chapters), do: "Could not detect any chapters in this PDF."
  def humanize_error(:not_configured), do: "GEMINI_API_KEY is not configured."
  def humanize_error(:rate_limited),
    do:
      "AI rate limit hit while summarizing. Wait a minute, then click Process PDF again — finished chapters are kept."

  def humanize_error(:invalid_batch_response),
    do: "AI returned an unexpected summary format. Please try processing again."
  def humanize_error(_), do: "Could not process this PDF. Please try again."
end
