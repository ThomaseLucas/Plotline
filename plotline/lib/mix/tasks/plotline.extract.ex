defmodule Mix.Tasks.Plotline.Extract do
  @moduledoc """
  Extracts chapter summaries from a configured adapter and stores them locally.

  ## Examples

      mix plotline.extract --book-id 1 --adapter json
      mix plotline.extract --book-id 1 --adapter json --chapter 2
      mix plotline.extract --book-id 1 --adapter sparknotes --from 1 --to 3

  """
  use Mix.Task

  @shortdoc "Extract chapter summaries into the database"

  @switches [
    book_id: :integer,
    adapter: :string,
    chapter: :integer,
    from: :integer,
    to: :integer
  ]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: @switches)

    with {:ok, book_id} <- fetch_required(opts, :book_id),
         {:ok, adapter} <- fetch_required(opts, :adapter) do
      run_extraction(book_id, adapter, opts)
    else
      {:error, message} ->
        Mix.shell().error(message)
        Mix.shell().info(usage())
        exit({:shutdown, 1})
    end
  end

  defp run_extraction(book_id, adapter, opts) do
    case Keyword.get(opts, :chapter) do
      nil ->
        import_opts =
          []
          |> maybe_put(:from, Keyword.get(opts, :from))
          |> maybe_put(:to, Keyword.get(opts, :to))

        case Plotline.Extraction.import_book(book_id, adapter, import_opts) do
          {:ok, stats} ->
            Mix.shell().info(
              "Imported #{stats.imported}/#{stats.total} chapters for book #{book_id} via #{adapter}."
            )

            if stats.errors != [] do
              Mix.shell().error("Errors:")
              Enum.each(stats.errors, fn {chapter, error} ->
                Mix.shell().error("  chapter #{chapter}: #{inspect(error)}")
              end)
            end

          {:error, reason} ->
            Mix.shell().error("Import failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      chapter ->
        case Plotline.Extraction.extract_chapter(book_id, chapter, adapter) do
          {:ok, summary} ->
            Mix.shell().info(
              "Stored chapter #{summary.chapter_number} summary (#{summary.source_name}) for book #{book_id}."
            )

          {:error, reason} ->
            Mix.shell().error("Extraction failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end
    end
  end

  defp fetch_required(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:error, "Missing required --#{key}"}
      value -> {:ok, value}
    end
  end

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp usage do
    """
    Usage:
      mix plotline.extract --book-id ID --adapter ADAPTER [--chapter N | --from N --to N]

    Adapters: #{Enum.join(Plotline.Extraction.list_adapters(), ", ")}
    """
  end
end
