defmodule Plotline.PdfUploads.ProcessorTest do
  use Plotline.DataCase, async: true

  import Plotline.AccountsFixtures

  alias Plotline.PdfUploads
  alias Plotline.PdfUploads.Processor
  alias Plotline.Summaries
  alias Plotline.UserBooks

  setup do
    dir = PdfUploads.upload_dir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    user = user_fixture()

    tmp = Path.join(System.tmp_dir!(), "plotline-proc-#{System.unique_integer([:positive])}.pdf")
    File.write!(tmp, "%PDF-1.4 fake")
    on_exit(fn -> File.rm(tmp) end)

    {:ok, upload} =
      PdfUploads.create_from_path(user.id, tmp, %{
        original_filename: "frankenstein.pdf",
        content_type: "application/pdf"
      })

    %{user: user, upload: upload}
  end

  test "process/1 creates book, user_book, summaries, and marks ready", %{
    user: user,
    upload: upload
  } do
    assert {:ok, processed} = Processor.process(upload.id)

    assert processed.status == "ready"
    assert processed.book_id

    book = Plotline.Books.get_book!(processed.book_id)
    assert book.title == "Frankenstein"
    assert book.author == "Mary Shelley"
    assert book.hardcover_id == "hc-frankenstein"
    assert book.cover_image_url == "https://example.com/frankenstein.jpg"
    assert book.total_chapters == 2

    assert UserBooks.get_user_book(user.id, book.id)
    summaries = Summaries.get_summaries_up_to(book.id, 99)
    assert length(summaries) == 2
    assert Enum.all?(summaries, &(&1.source_name == "pdf_ai"))
  end

  test "list_pending_uploads_for_user hides linked uploads", %{user: user, upload: upload} do
    assert [%{id: id}] = PdfUploads.list_pending_uploads_for_user(user.id)
    assert id == upload.id

    assert {:ok, _} = Processor.process(upload.id)
    assert PdfUploads.list_pending_uploads_for_user(user.id) == []
  end
end
