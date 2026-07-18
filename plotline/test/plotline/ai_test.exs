defmodule Plotline.AITest do
  use Plotline.DataCase, async: true

  import Plotline.AccountsFixtures

  alias Plotline.AI
  alias Plotline.Books
  alias Plotline.Extraction
  alias Plotline.UserBooks

  setup do
    user = user_fixture()

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

    %{user_book: Map.put(user_book, :book, book)}
  end

  test "enabled?/0 reflects configured api key" do
    assert AI.enabled?()
  end

  test "chat/2 returns assistant reply from configured provider", %{user_book: user_book} do
    assert {:ok, reply} = AI.chat(user_book, "Who is Elizabeth?")
    assert reply =~ "Test assistant reply"
  end

  test "recap/1 uses recap prompt", %{user_book: user_book} do
    assert {:ok, reply} = AI.recap(user_book)
    assert reply =~ "recap"
  end

  test "chat/2 rejects when chapter progress is zero", %{user_book: user_book} do
    user_book = %{user_book | current_chapter_number: 0}
    assert {:error, :no_progress} = AI.chat(user_book, "Hello")
  end
end
