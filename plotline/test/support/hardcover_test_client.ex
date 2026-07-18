defmodule Plotline.Hardcover.TestClient do
  @moduledoc false

  def search_books("Frankenstein" <> _rest, _token) do
    {:ok,
     [
       %{
         hardcover_id: "hc-frankenstein",
         title: "Frankenstein",
         author: "Mary Shelley",
         cover_image_url: "https://example.com/frankenstein.jpg"
       }
     ]}
  end

  def search_books(_query, _token), do: {:ok, []}
end
