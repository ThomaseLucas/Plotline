defmodule Plotline.AI.PromptTest do
  use ExUnit.Case, async: true

  alias Plotline.AI.Prompt
  alias Plotline.Books.Book
  alias Plotline.Summaries.ChapterSummary
  alias Plotline.UserBooks.UserBook

  test "system_instruction includes only provided summaries and current chapter" do
    user_book = %UserBook{
      current_chapter_number: 2,
      book: %Book{title: "Pride and Prejudice", author: "Jane Austen"}
    }

    summaries = [
      %ChapterSummary{chapter_number: 1, summary_text: "Netherfield arrives."},
      %ChapterSummary{chapter_number: 2, summary_text: "Mr. Bennet visits."}
    ]

    instruction = Prompt.system_instruction(user_book, summaries)

    assert instruction =~ "Pride and Prejudice"
    assert instruction =~ "Jane Austen"
    assert instruction =~ "current chapter is 2"
    assert instruction =~ "chapters 1 through 2"
    assert instruction =~ "Netherfield arrives."
    assert instruction =~ "Mr. Bennet visits."
    assert instruction =~ "## Heading"
    refute instruction =~ "Chapter 3"
  end

  test "chapter_batch_user includes each chapter heading" do
    chapters = [
      %{number: 1, title: "Chapter 1", text: String.duplicate("alpha ", 20)},
      %{number: 2, title: "Chapter 2", text: String.duplicate("beta ", 20)}
    ]

    message = Prompt.chapter_batch_user(chapters)

    assert message =~ "CHAPTER 1"
    assert message =~ "CHAPTER 2"
    assert message =~ "alpha"
  end
end
