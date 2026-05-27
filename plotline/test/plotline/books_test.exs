defmodule Plotline.BooksTest do
  use Plotline.DataCase, async: true

  alias Plotline.Books
  alias Plotline.Books.Book

  @valid_attrs %{
    title: "The Test Book",
    author: "Jane Author",
    total_chapters: 10,
    hardcover_id: "HC-123",
    cover_image_url: "http://example.com/cover.jpg"
  }

  @invalid_attrs %{
    title: "",
    author: nil
  }

  test "create_book/1 with valid data creates a book" do
    assert {:ok, %Book{} = book} = Books.create_book(@valid_attrs)
    assert book.title == "The Test Book"
    assert book.author == "Jane Author"
    assert book.total_chapters == 10
  end

  test "create_book/1 with invalid data returns error changeset" do
    assert {:error, changeset} = Books.create_book(@invalid_attrs)
    errors = errors_on(changeset)
    assert errors.title != nil or errors.author != nil
  end

  test "changeset enforces validations and unique constraint" do
    # Insert the first book
    assert {:ok, %Book{} = book1} = Books.create_book(@valid_attrs)

    # Duplicate by title/author should violate unique constraint (index name: books_title_author_index)
    dup_attrs = Map.put(@valid_attrs, :hardcover_id, "HC-456")
    assert {:error, changeset} = Books.create_book(dup_attrs)
    dup_errors = errors_on(changeset)
    assert dup_errors.title || dup_errors.author

    # list_books returns the inserted book
    [listed] = Books.list_books()
    assert listed.id == book1.id
  end
end
