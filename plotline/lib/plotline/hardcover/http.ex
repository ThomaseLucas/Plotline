defmodule Plotline.Hardcover.HTTP do
  @moduledoc false

  @endpoint "https://api.hardcover.app/v1/graphql"
  @user_agent "Plotline/0.1 (senior-project; local-dev)"

  @search_query """
  query SearchBooks($query: String!) {
    search(query: $query, query_type: "Book", per_page: 5, page: 1) {
      results
      ids
    }
  }
  """

  def search_books(query, api_token) when is_binary(query) and is_binary(api_token) do
    headers = [
      {"authorization", authorization_header(api_token)},
      {"content-type", "application/json"},
      {"user-agent", @user_agent}
    ]

    payload = %{
      query: @search_query,
      variables: %{query: query}
    }

    case Req.post(@endpoint, headers: headers, json: payload, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"data" => %{"search" => search}}}} ->
        {:ok, normalize_results(search)}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, {:graphql_errors, errors}}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_results(%{"results" => results} = search) do
    ids = Map.get(search, "ids") || []

    hits =
      cond do
        is_list(results) ->
          results

        is_map(results) and is_list(results["hits"]) ->
          Enum.map(results["hits"], fn
            %{"document" => doc} when is_map(doc) -> doc
            hit when is_map(hit) -> hit
          end)

        is_map(results) and is_list(results["matches"]) ->
          results["matches"]

        true ->
          []
      end

    hits
    |> Enum.with_index()
    |> Enum.map(fn {hit, index} ->
      id = hit["id"] || hit["book_id"] || Enum.at(ids, index) || hit["slug"]

      %{
        hardcover_id: id && to_string(id),
        title: hit["title"] || hit["name"],
        author: first_author(hit),
        cover_image_url: cover_url(hit)
      }
    end)
    |> Enum.filter(fn hit -> is_binary(hit.title) and hit.title != "" end)
  end

  defp normalize_results(_), do: []

  defp first_author(%{"author_names" => [name | _]}) when is_binary(name), do: name
  defp first_author(%{"author_names" => name}) when is_binary(name), do: name
  defp first_author(%{"author" => name}) when is_binary(name), do: name
  defp first_author(%{"authors" => [%{"name" => name} | _]}), do: name
  defp first_author(_), do: nil

  defp cover_url(%{"image" => %{"url" => url}}) when is_binary(url), do: url
  defp cover_url(%{"image" => url}) when is_binary(url), do: url
  defp cover_url(%{"cover_image_url" => url}) when is_binary(url), do: url
  defp cover_url(%{"cached_image" => %{"url" => url}}) when is_binary(url), do: url
  defp cover_url(_), do: nil

  defp authorization_header(token) do
    if String.starts_with?(token, "Bearer ") do
      token
    else
      "Bearer #{token}"
    end
  end
end
