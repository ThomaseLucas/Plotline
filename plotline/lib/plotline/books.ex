defmodule Plotline.Books do
  @moduledoc "Context for books being stored."
  alias Plotline.Repo
  alias Plotline.Books.Book

  def list_books, do: Repo.all(Book)

  def create_book(attrs) do
    %Book{}
    |> Book.changeset(attrs)
    |> Repo.insert()
  end

  def get_book!(id), do: Repo.get!(Book, id)
end
