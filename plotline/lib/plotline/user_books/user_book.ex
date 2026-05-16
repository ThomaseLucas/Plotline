defmodule Plotline.UserBooks.UserBook do
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:current_chapter_number]
  @required_fields [:current_chapter_number]

  schema "user_books" do
    field(:current_chapter_number, :integer, default: 0)

    belongs_to(:user, Plotline.Accounts.User)
    belongs_to(:book, Plotline.Books.Book)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates and casts data for tracking a user's reading progress.
  """
  def changeset(user_book, attrs) do
    user_book
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_number(:current_chapter_number, greater_than_or_equal_to: 0)
    |> assoc_constraint(:user)
    |> assoc_constraint(:book)
    |> unique_constraint(:book_id, name: :user_books_user_id_book_id_index)
  end
end
