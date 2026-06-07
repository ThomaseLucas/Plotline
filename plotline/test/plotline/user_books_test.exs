defmodule Plotline.UserBooksTest do
  use Plotline.DataCase, async: true

  alias Plotline.UserBooks
  alias Plotline.UserBooks.UserBook
  alias Plotline.Books

  import Plotline.AccountsFixtures

  test "create_user_book/3 with valid data creates a user_book" do
    user = user_fixture()

    {:ok, book} =
      Books.create_book(%{title: "Test Book A", author: "Author A", total_chapters: 5})

    assert {:ok, %UserBook{} = ub} =
             UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 2})

    assert ub.user_id == user.id
    assert ub.book_id == book.id
    assert ub.current_chapter_number == 2
  end

  test "create_user_book/3 with no attrs uses default chapter number" do
    user = user_fixture()

    {:ok, book} =
      Books.create_book(%{title: "Test Book B", author: "Author B", total_chapters: 3})

    assert {:ok, %UserBook{} = ub} = UserBooks.create_user_book(user.id, book.id, %{})
    assert ub.current_chapter_number == 0
  end

  test "unique constraint prevents creating duplicate user_book for same user and book" do
    user = user_fixture()
    {:ok, book} = Books.create_book(%{title: "Unique Book", author: "U", total_chapters: 1})

    assert {:ok, %UserBook{}} =
             UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 0})

    assert {:error, changeset} =
             UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 1})

    assert errors_on(changeset).book_id
  end

  test "get_user_book/2, list_user_books/1 and ordering by book_id" do
    user = user_fixture()
    {:ok, book1} = Books.create_book(%{title: "A Book", author: "A", total_chapters: 2})
    {:ok, book2} = Books.create_book(%{title: "B Book", author: "B", total_chapters: 3})

    {:ok, ub1} = UserBooks.create_user_book(user.id, book1.id, %{current_chapter_number: 1})
    {:ok, _ub2} = UserBooks.create_user_book(user.id, book2.id, %{current_chapter_number: 2})

    list = UserBooks.list_user_books(user.id)
    assert Enum.map(list, & &1.book_id) == Enum.sort(Enum.map(list, & &1.book_id))

    assert UserBooks.get_user_book(user.id, book1.id).id == ub1.id
  end

  test "update_user_book/2 updates fields and validates numeric constraints" do
    user = user_fixture()
    {:ok, book} = Books.create_book(%{title: "Update Book", author: "A", total_chapters: 4})

    {:ok, ub} = UserBooks.create_user_book(user.id, book.id, %{current_chapter_number: 0})

    assert {:ok, %UserBook{} = updated} =
             UserBooks.update_user_book(ub, %{current_chapter_number: 1})

    assert updated.current_chapter_number == 1

    assert {:error, changeset} =
             UserBooks.update_user_book(updated, %{current_chapter_number: -1})

    assert %{current_chapter_number: _} = errors_on(changeset)
  end
end
