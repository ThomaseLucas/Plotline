defmodule Plotline.PdfUploads.PdfUpload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pdf_uploads" do
    field(:original_filename, :string)
    field(:stored_path, :string)
    field(:content_type, :string)
    field(:byte_size, :integer)
    field(:status, :string, default: "uploaded")

    belongs_to(:user, Plotline.Accounts.User)
    belongs_to(:book, Plotline.Books.Book)

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(uploaded processing ready failed)

  def changeset(pdf_upload, attrs) do
    pdf_upload
    |> cast(attrs, [
      :original_filename,
      :stored_path,
      :content_type,
      :byte_size,
      :status,
      :user_id,
      :book_id
    ])
    |> validate_required([
      :original_filename,
      :stored_path,
      :content_type,
      :byte_size,
      :user_id
    ])
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_format(:content_type, ~r/^application\/pdf$/i,
      message: "must be a PDF"
    )
    |> assoc_constraint(:user)
    |> assoc_constraint(:book)
    |> unique_constraint(:stored_path)
  end
end
