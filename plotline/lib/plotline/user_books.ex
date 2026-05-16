defmodule Plotline.UserBooks do
  @moduledoc "Context for user reading progress."

  import Ecto.Query, warn: false

  alias Plotline.Repo
  alias Plotline.UserBooks.UserBook

  def list_user_books(user_id) do
    from(ub in UserBook,
      where: ub.user_id == ^user_id,
      order_by: [asc: ub.book_id]
    )
    |> Repo.all()
  end

  def get_user_book!(id), do: Repo.get!(UserBook, id)

  def get_user_book(user_id, book_id) do
    Repo.get_by(UserBook, user_id: user_id, book_id: book_id)
  end

  def create_user_book(user_id, book_id, attrs \\ %{}) do
    %UserBook{user_id: user_id, book_id: book_id}
    |> UserBook.changeset(attrs)
    |> Repo.insert()
  end

  def update_user_book(%UserBook{} = user_book, attrs) do
    user_book
    |> UserBook.changeset(attrs)
    |> Repo.update()
  end
end
