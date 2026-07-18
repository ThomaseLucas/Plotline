defmodule Plotline.BookRequests.BookRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "book_requests" do
    field(:title, :string)
    field(:author, :string)
    field(:notes, :string)
    field(:status, :string, default: "pending")

    belongs_to(:user, Plotline.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(book_request, attrs) do
    book_request
    |> cast(attrs, [:title, :author, :notes, :status])
    |> validate_required([:title, :author])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:author, min: 1, max: 255)
    |> validate_length(:notes, max: 2000)
    |> validate_inclusion(:status, ["pending", "reviewed", "added", "declined"])
    |> assoc_constraint(:user)
  end
end
