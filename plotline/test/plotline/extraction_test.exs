defmodule Plotline.ExtractionTest do
  use Plotline.DataCase, async: true

  alias Plotline.{Books, Extraction, Summaries}

  @demo_book %{
    title: "Pride and Prejudice",
    author: "Jane Austen",
    total_chapters: 61
  }

  setup do
    {:ok, book} = Books.create_book(@demo_book)
    %{book: book}
  end

  test "extract_chapter/3 loads curated JSON summaries", %{book: book} do
    assert {:ok, summary} = Extraction.extract_chapter(book.id, 1, "json")
    assert summary.chapter_number == 1
    assert summary.source_name == "CuratedDemo"
    assert summary.summary_text =~ "Mrs. Bennet"
  end

  test "import_book/2 loads all chapters from JSON adapter", %{book: book} do
    assert {:ok, stats} = Extraction.import_book(book.id, "json")
    assert stats.imported == 3
    assert stats.total == 3
    assert stats.errors == []

    summaries = Summaries.get_summaries_up_to(book.id, 3)
    assert length(summaries) == 3
    assert Enum.map(summaries, & &1.chapter_number) == [1, 2, 3]
  end

  test "upsert_summary/1 replaces existing summary for same source", %{book: book} do
    attrs = %{
      book_id: book.id,
      chapter_number: 1,
      summary_text: "Original text.",
      source_name: "CuratedDemo"
    }

    assert {:ok, first} = Summaries.upsert_summary(attrs)
    assert {:ok, second} = Summaries.upsert_summary(Map.put(attrs, :summary_text, "Updated text."))

    assert first.id == second.id
    assert second.summary_text == "Updated text."
  end

  test "get_summaries_up_to/2 returns spoiler-safe chapter filter", %{book: book} do
    Extraction.import_book(book.id, "json")

    summaries = Summaries.get_summaries_up_to(book.id, 2)
    assert length(summaries) == 2
    refute Enum.any?(summaries, &(&1.chapter_number > 2))
  end

  test "extract_chapter/3 returns error for unknown adapter", %{book: book} do
    assert {:error, :unknown_adapter} = Extraction.extract_chapter(book.id, 1, "missing")
  end
end
