defmodule Plotline.Extraction.Adapter do
  @moduledoc """
  Behaviour for source-specific chapter summary extraction adapters.

  Each adapter fetches summary text from one approved source and returns
  normalized attributes ready for `Plotline.Summaries.upsert_summary/1`.
  """

  alias Plotline.Books.Book

  @type summary_attrs :: %{
          required(:summary_text) => String.t(),
          optional(:source_url) => String.t() | nil,
          optional(:scraped_at) => DateTime.t()
        }

  @callback source_name() :: String.t()

  @doc """
  Fetches a single chapter summary for the given book.

  Returns `{:ok, summary_attrs}` or `{:error, reason}`.
  """
  @callback fetch_chapter_summary(book :: Book.t(), chapter_number :: pos_integer()) ::
              {:ok, summary_attrs()} | {:error, term()}
end
