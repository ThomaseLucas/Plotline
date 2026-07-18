defmodule PlotlineWeb.LibraryLiveTest do
  use PlotlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plotline.{Books, Extraction, PdfUploads, UserBooks}
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog

  setup do
    Catalog.clear_cache!()
    Catalog.load_disk!()
    :ok
  end

  describe "Index" do
    setup :register_and_log_in_user

    test "lists empty library", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/library")
      assert html =~ "My Library"
      assert html =~ "No books yet"
      assert html =~ "Upload PDF"
      assert has_element?(view, "#library-empty")
      assert has_element?(view, "#upload-pdf-button")
    end

    test "navigates to upload page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/library")

      {:ok, _upload_view, html} =
        view
        |> element("#upload-pdf-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/library/upload")

      assert html =~ "Upload PDF"
      assert html =~ "Select PDF"
      assert html =~ "pdf-upload-form"
    end

    test "lists user books", %{conn: conn, user: user} do
      {:ok, book} =
        Books.create_book(%{
          title: "Pride and Prejudice",
          author: "Jane Austen",
          total_chapters: 61
        })

      {:ok, _} = UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 5})

      {:ok, _view, html} = live(conn, ~p"/library")
      assert html =~ "Pride and Prejudice"
      assert html =~ "Jane Austen"
      assert html =~ "Ch. 5 of 61"
      assert html =~ "aria-valuenow=\"5\""
      assert html =~ "width: 8%"
    end

    test "deletes a user book from the library", %{conn: conn, user: user} do
      {:ok, book} =
        Books.create_book(%{
          title: "1984",
          author: "George Orwell",
          total_chapters: 24
        })

      {:ok, user_book} =
        UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 1})

      {:ok, view, _html} = live(conn, ~p"/library")
      assert has_element?(view, "#user-book-#{user_book.id}")
      assert has_element?(view, "#delete-user-book-#{user_book.id}")

      html =
        view
        |> element("#delete-user-book-#{user_book.id}")
        |> render_click()

      refute html =~ "1984"
      refute has_element?(view, "#user-book-#{user_book.id}")
      assert UserBooks.get_user_book(user.id, book.id) == nil
    end

    test "lists uploaded pdfs with derived metadata", %{conn: conn, user: user} do
      dir = PdfUploads.upload_dir()
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      tmp = Path.join(System.tmp_dir!(), "plotline-lib-#{System.unique_integer([:positive])}.pdf")
      File.write!(tmp, "%PDF-1.4 frankenstein")
      on_exit(fn -> File.rm(tmp) end)

      {:ok, upload} =
        PdfUploads.create_from_path(user.id, tmp, %{
          original_filename: "frankenstein.pdf",
          content_type: "application/pdf"
        })

      {:ok, view, html} = live(conn, ~p"/library")
      assert html =~ "Frankenstein"
      assert html =~ "Author unknown"
      assert html =~ "Uploaded · chapters pending"
      assert has_element?(view, "#pdf-upload-#{upload.id}")
      refute has_element?(view, "#library-empty")
    end

    test "requires authentication", %{conn: _conn} do
      conn = build_conn()
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/library")
    end
  end

  describe "New" do
    setup :register_and_log_in_user

    test "searches catalog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/library/new")

      html =
        view
        |> form("#catalog-search-form", search: "1984")
        |> render_change()

      assert html =~ "1984"
      assert html =~ "George Orwell"
      assert html =~ "id=\"catalog-1984\""
      refute html =~ "id=\"catalog-pride-and-prejudice\""
    end

    test "shows message when catalog reload is rate limited", %{conn: conn} do
      Application.put_env(:plotline, Plotline.CatalogSync, cooldown_ms: 60_000)
      on_exit(fn -> Application.put_env(:plotline, Plotline.CatalogSync, cooldown_ms: 0) end)

      Agent.update(Plotline.CatalogSync, fn _ ->
        %{syncing: false, last_finished_at: System.monotonic_time(:millisecond)}
      end)

      {:ok, view, _html} = live(conn, ~p"/library/new")

      html =
        view
        |> element("#reload-catalog-button")
        |> render_click()

      assert html =~ "Please wait"
      assert html =~ "before reloading the catalog again"
    end

    test "submits a book request", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/library/new")

      assert html =~ "book-request-section"
      assert html =~ "find your book"

      view
      |> form("#book-request-form", book_request: %{
        "title" => "Dune",
        "author" => "Frank Herbert",
        "notes" => "Please add this classic"
      })
      |> render_submit()

      assert render(view) =~ "Thanks! Your book request was submitted."
    end

    test "adds book with json summaries without network", %{conn: conn, user: user} do
      # Pre-import via json adapter (same title as catalog fixture)
      {:ok, book} =
        Books.create_book(%{
          title: "Pride and Prejudice",
          author: "Jane Austen",
          total_chapters: 61,
          chapter_summaries_slug: "pride-and-prejudice"
        })

      {:ok, _} = Extraction.import_book(book.id, "json")

      {:ok, view, _html} = live(conn, ~p"/library/new")

      view
      |> element("#add-book-pride-and-prejudice")
      |> render_click()

      assert UserBooks.get_user_book(user.id, book.id)

      assert_redirect(view, ~p"/library/#{UserBooks.get_user_book(user.id, book.id).id}")
    end
  end

  describe "Show" do
    setup :register_and_log_in_user

    setup %{user: user} do
      {:ok, book} =
        Books.create_book(%{
          title: "Pride and Prejudice",
          author: "Jane Austen",
          total_chapters: 61,
          chapter_summaries_slug: "pride-and-prejudice"
        })

      {:ok, _} = Extraction.import_book(book.id, "json")

      {:ok, user_book} =
        UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 2})

      %{user_book: user_book, book: book}
    end

    test "shows reading assistant section", %{conn: conn, user_book: user_book} do
      {:ok, _view, html} = live(conn, ~p"/library/#{user_book.id}")

      assert html =~ "Reading assistant"
      assert html =~ "Recap so far"
    end

    test "shows spoiler-safe summaries", %{conn: conn, user_book: user_book} do
      {:ok, _view, html} = live(conn, ~p"/library/#{user_book.id}")

      assert html =~ "Pride and Prejudice"
      assert html =~ "chapters 1–2"
      assert html =~ "summary-chapter-1"
      assert html =~ "summary-chapter-2"
      refute html =~ "id=\"summary-chapter-3\""
    end

    test "updates chapter and refreshes recall", %{conn: conn, user_book: user_book} do
      {:ok, view, _html} = live(conn, ~p"/library/#{user_book.id}")

      view
      |> form("#chapter-form", user_book: %{current_chapter_number: 3})
      |> render_submit()

      html = render(view)
      assert html =~ "chapters 1–3"
      assert html =~ "summary-chapter-3"
    end
  end

  describe "Upload" do
    setup :register_and_log_in_user

    test "deletes uploaded pdf and metadata", %{conn: conn, user: user} do
      dir = PdfUploads.upload_dir()
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      tmp = Path.join(System.tmp_dir!(), "plotline-lv-del-#{System.unique_integer([:positive])}.pdf")
      File.write!(tmp, "%PDF-1.4 delete via liveview")
      on_exit(fn -> File.rm(tmp) end)

      {:ok, upload} =
        PdfUploads.create_from_path(user.id, tmp, %{
          original_filename: "frankenstein.pdf",
          content_type: "application/pdf"
        })

      path = PdfUploads.absolute_path(upload)
      assert File.exists?(path)

      {:ok, view, html} = live(conn, ~p"/library/upload")
      assert html =~ "frankenstein.pdf"
      assert has_element?(view, "#delete-pdf-#{upload.id}")

      html =
        view
        |> element("#delete-pdf-#{upload.id}")
        |> render_click()

      refute html =~ "frankenstein.pdf"
      refute File.exists?(path)
      assert PdfUploads.get_upload_for_user(user.id, upload.id) == nil
    end

    test "process button starts pdf processing", %{conn: conn, user: user} do
      dir = PdfUploads.upload_dir()
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      tmp = Path.join(System.tmp_dir!(), "plotline-lv-proc-#{System.unique_integer([:positive])}.pdf")
      File.write!(tmp, "%PDF-1.4 process via liveview")
      on_exit(fn -> File.rm(tmp) end)

      {:ok, upload} =
        PdfUploads.create_from_path(user.id, tmp, %{
          original_filename: "frankenstein.pdf",
          content_type: "application/pdf"
        })

      {:ok, view, _html} = live(conn, ~p"/library/upload")
      assert has_element?(view, "#process-pdf-#{upload.id}")

      html =
        view
        |> element("#process-pdf-#{upload.id}")
        |> render_click()

      assert html =~ "PDF processed"
      assert PdfUploads.get_upload!(upload.id).status == "ready"
    end
  end
end
