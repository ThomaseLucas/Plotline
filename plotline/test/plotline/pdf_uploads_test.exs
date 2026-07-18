defmodule Plotline.PdfUploadsTest do
  use Plotline.DataCase, async: true

  import Plotline.AccountsFixtures

  alias Plotline.PdfUploads

  setup do
    dir = PdfUploads.upload_dir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{user: user_fixture(), dir: dir}
  end

  test "create_from_path/3 stores file on disk and metadata in db", %{user: user, dir: dir} do
    tmp = Path.join(System.tmp_dir!(), "plotline-sample-#{System.unique_integer([:positive])}.pdf")
    File.write!(tmp, "%PDF-1.4 sample content for plotline")
    on_exit(fn -> File.rm(tmp) end)

    assert {:ok, upload} =
             PdfUploads.create_from_path(user.id, tmp, %{
               original_filename: "pride.pdf",
               content_type: "application/pdf",
               byte_size: byte_size("%PDF-1.4 sample content for plotline")
             })

    assert upload.original_filename == "pride.pdf"
    assert upload.status == "uploaded"
    assert upload.user_id == user.id
    assert File.exists?(Path.join(dir, upload.stored_path))
    refute String.contains?(upload.stored_path, "..")
  end

  test "delete_upload/1 removes metadata and file", %{user: user} do
    tmp = Path.join(System.tmp_dir!(), "plotline-del-#{System.unique_integer([:positive])}.pdf")
    File.write!(tmp, "%PDF-1.4 delete me")
    on_exit(fn -> File.rm(tmp) end)

    {:ok, upload} =
      PdfUploads.create_from_path(user.id, tmp, %{
        original_filename: "delete.pdf",
        content_type: "application/pdf"
      })

    path = PdfUploads.absolute_path(upload)
    assert File.exists?(path)

    assert {:ok, _} = PdfUploads.delete_upload(upload)
    refute File.exists?(path)
  end

  test "display_title/1 humanizes the filename", %{user: user} do
    tmp = Path.join(System.tmp_dir!(), "plotline-title-#{System.unique_integer([:positive])}.pdf")
    File.write!(tmp, "%PDF-1.4 title")
    on_exit(fn -> File.rm(tmp) end)

    {:ok, upload} =
      PdfUploads.create_from_path(user.id, tmp, %{
        original_filename: "pride_and_prejudice.pdf",
        content_type: "application/pdf"
      })

    assert PdfUploads.display_title(upload) == "Pride And Prejudice"
  end
end
