defmodule Mix.Tasks.Plotline.SyncCatalog do
  @moduledoc """
  Downloads the full chapter-summaries.com book catalog to disk.

      mix plotline.sync_catalog

  Writes `priv/data/chapter_summaries_catalog.json` (97 books as of 2026).
  The app uses this file for fast availability checks without hitting the network.
  """
  use Mix.Task

  @shortdoc "Sync chapter-summaries.com book catalog to disk"

  @impl Mix.Task
  def run(_argv) do
    Mix.Task.run("app.start")

    books = Plotline.Extraction.Adapters.ChapterSummaries.Catalog.refresh!()

    Mix.shell().info("Synced #{length(books)} books to priv/data/chapter_summaries_catalog.json.")
  end
end
