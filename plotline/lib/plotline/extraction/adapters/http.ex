defmodule Plotline.Extraction.Adapters.Http do
  @moduledoc """
  Shared HTTP helpers for web-based extraction adapters.

  Uses `Req` per project conventions. Submodules implement site-specific
  URL building and HTML parsing.
  """

  @doc false
  def fetch_html(url, opts \\ []) do
    case Req.get(url, Keyword.merge([retry: false, receive_timeout: 15_000], opts)) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def strip_html(html) when is_binary(html) do
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, " ")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, " ")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
