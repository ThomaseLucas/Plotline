defmodule Plotline.PdfUploads do
  @moduledoc """
  Stores PDF metadata in the database and file bytes on disk.

  PDFs are never stored as binary columns in Postgres — only a path and
  metadata are persisted.
  """

  import Ecto.Query, warn: false

  alias Plotline.PdfUploads.PdfUpload
  alias Plotline.Repo

  @doc "Returns the configured upload directory, creating it if needed."
  def upload_dir do
    dir =
      Application.get_env(:plotline, __MODULE__, [])
      |> Keyword.get(:upload_dir, "priv/uploads/pdfs")
      |> Path.expand()

    File.mkdir_p!(dir)
    dir
  end

  @doc "Absolute filesystem path for a stored relative path."
  def absolute_path(%PdfUpload{stored_path: path}), do: absolute_path(path)

  def absolute_path(stored_path) when is_binary(stored_path) do
    Path.join(upload_dir(), stored_path)
  end

  def get_upload!(id), do: Repo.get!(PdfUpload, id)

  def get_upload_for_user(user_id, id) do
    Repo.get_by(PdfUpload, id: id, user_id: user_id)
  end

  def list_uploads_for_user(user_id) do
    from(p in PdfUpload,
      where: p.user_id == ^user_id,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Uploads that are not yet linked to a library book."
  def list_pending_uploads_for_user(user_id) do
    from(p in PdfUpload,
      where: p.user_id == ^user_id and is_nil(p.book_id),
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  def update_upload(%PdfUpload{} = upload, attrs) do
    upload
    |> PdfUpload.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Copies a temporary uploaded file into the upload directory and inserts metadata.

  `tmp_path` is the ephemeral LiveView upload path. The PDF itself stays on disk;
  only metadata goes in the database.
  """
  def create_from_path(user_id, tmp_path, attrs) when is_integer(user_id) do
    original_filename = Map.fetch!(attrs, :original_filename)
    content_type = Map.get(attrs, :content_type, "application/pdf")
    byte_size = Map.get_lazy(attrs, :byte_size, fn -> File.stat!(tmp_path).size end)

    stored_name = "#{user_id}_#{Ecto.UUID.generate()}.pdf"
    dest = Path.join(upload_dir(), stored_name)

    with :ok <- File.cp(tmp_path, dest),
         {:ok, upload} <-
           %PdfUpload{}
           |> PdfUpload.changeset(%{
             user_id: user_id,
             original_filename: original_filename,
             stored_path: stored_name,
             content_type: content_type,
             byte_size: byte_size,
             status: "uploaded"
           })
           |> Repo.insert() do
      {:ok, upload}
    else
      {:error, reason} ->
        _ = File.rm(dest)
        {:error, reason}
    end
  end

  def delete_upload(%PdfUpload{} = upload) do
    path = absolute_path(upload)

    case Repo.delete(upload) do
      {:ok, deleted} ->
        _ = File.rm(path)
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc """
  Best-effort display title from the original filename.

  PDFs do not yet store title/author metadata — this is a placeholder until
  extraction fills those fields.
  """
  def display_title(%PdfUpload{original_filename: name}) when is_binary(name) do
    name
    |> Path.rootname()
    |> String.replace(~r/[_\-]+/, " ")
    |> String.trim()
    |> case do
      "" -> "Untitled PDF"
      title -> title |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  def format_bytes(bytes) when is_integer(bytes) and bytes >= 1_000_000 do
    "#{Float.round(bytes / 1_000_000, 1)} MB"
  end

  def format_bytes(bytes) when is_integer(bytes) and bytes >= 1_000 do
    "#{Float.round(bytes / 1_000, 1)} KB"
  end

  def format_bytes(bytes) when is_integer(bytes), do: "#{bytes} B"
  def format_bytes(_), do: "—"
end
