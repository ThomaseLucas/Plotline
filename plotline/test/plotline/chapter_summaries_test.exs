defmodule Plotline.ChapterSummariesTest do
  use Plotline.DataCase, async: true

  alias Plotline.Summaries
  alias Plotline.Summaries.ChapterSummary
  alias Plotline.Books

  @valid_attrs %{
    chapter_number: 3,
    summary_text: "This chapter is about how important tests are.",
    source_name: "BookSummary",
    source_url: "booksummary.com"
  }

  @invalid_attrs %{
    book_id: nil,
    chapter_number: nil,
    summary_text: nil,
    source_name: nil
  }

  test "create_summary/1 with valid data creates a summary for a chapter in a book" do
    # create a book to associate the summary with
    {:ok, book} = Books.create_book(%{title: "Test Book", author: "Author", total_chapters: 20})

    {:ok, scraped, _offset} = DateTime.from_iso8601("2024-05-18T14:30:00Z")

    attrs = @valid_attrs |> Map.put(:book_id, book.id) |> Map.put(:scraped_at, scraped)

    assert {:ok, %ChapterSummary{} = summary} = Summaries.create_summary(attrs)
    assert summary.book_id == book.id
    assert summary.chapter_number == 3
    assert summary.summary_text == "This chapter is about how important tests are."
    assert summary.source_name == "BookSummary"
  end

  test "create_summary/1 with invalid data returns error changeset" do
    assert {:error, changeset} = Summaries.create_summary(@invalid_attrs)
    errors = errors_on(changeset)
    assert errors.book_id != nil or errors.chapter_number != nil
  end
end
