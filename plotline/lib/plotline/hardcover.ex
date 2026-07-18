defmodule Plotline.Hardcover do
  @moduledoc """
  Minimal Hardcover GraphQL client for book metadata enrichment.

  Configure with `HARDCOVER_API_TOKEN` (Hardcover account settings → API).
  """

  @doc "Returns true when an API token is configured."
  def configured? do
    case api_token() do
      token when is_binary(token) and token != "" -> true
      _ -> false
    end
  end

  @doc """
  Searches Hardcover for books matching `query`.

  Returns `{:ok, [hit]}` where each hit is:

      %{hardcover_id: String.t(), title: String.t(), author: String.t() | nil,
        cover_image_url: String.t() | nil}

  or `{:error, reason}`. When not configured, returns `{:ok, []}`.
  """
  def search_books(query) when is_binary(query) do
    query = String.trim(query)

    cond do
      query == "" ->
        {:ok, []}

      not configured?() ->
        {:ok, []}

      true ->
        client().search_books(query, api_token())
    end
  end

  @doc """
  Returns the best matching book for `query`, or `nil` when none / not configured.
  """
  def best_match(query) when is_binary(query) do
    case search_books(query) do
      {:ok, [hit | _]} -> hit
      {:ok, []} -> nil
      {:error, _} -> nil
    end
  end

  defp client do
    Application.get_env(:plotline, __MODULE__, [])
    |> Keyword.get(:client, Plotline.Hardcover.HTTP)
  end

  defp api_token do
    Application.get_env(:plotline, __MODULE__, [])
    |> Keyword.get(:api_token)
    |> case do
      token when is_binary(token) and token != "" -> token
      _ -> System.get_env("HARDCOVER_API_TOKEN")
    end
  end
end
