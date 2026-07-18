defmodule Plotline.Pdf.TextExtractor do
  @moduledoc """
  Extracts plain text from a PDF using Poppler's `pdftotext`.

  Requires `pdftotext` on PATH (`brew install poppler`, `apt install poppler-utils`,
  or Poppler for Windows).
  """

  @doc """
  Extracts text from a PDF file path.

  Returns `{:ok, text}` or `{:error, reason}` where reason is
  `:pdftotext_missing`, `:empty_text`, `:file_not_found`, or `{:pdftotext_failed, status, stderr}`.
  """
  def extract(path) when is_binary(path) do
    cond do
      not File.exists?(path) ->
        {:error, :file_not_found}

      not binary_available?() ->
        {:error, :pdftotext_missing}

      true ->
        run_pdftotext(path)
    end
  end

  @doc "Returns true when `pdftotext` is available on PATH."
  def binary_available? do
    case System.find_executable("pdftotext") do
      nil -> false
      _ -> true
    end
  end

  defp run_pdftotext(path) do
    # "-" writes text to stdout
    args = ["-layout", "-enc", "UTF-8", path, "-"]

    case System.cmd("pdftotext", args, stderr_to_stdout: true) do
      {output, 0} ->
        text = String.trim(output)

        if text == "" do
          {:error, :empty_text}
        else
          {:ok, text}
        end

      {output, status} ->
        {:error, {:pdftotext_failed, status, String.trim(output)}}
    end
  end
end
