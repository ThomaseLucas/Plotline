defmodule Plotline.ChapterSummariesTest do
  use Plotline.DataCase, async: true

  alias Plotline.Books
  alias Plotline.Extraction.Adapters.ChapterSummaries
  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog

  @browse_fixture "test/support/fixtures/chapter_summaries/browse_page.html"
  @chapters_fixture "test/support/fixtures/chapter_summaries/chapters_page.html"

  setup do
    Catalog.clear_cache!()
    Catalog.load_disk!()
    :ok
  end

  test "parse_browse_page/1 extracts book metadata from browse HTML" do
    html = File.read!(@browse_fixture)

    [first | _] = Catalog.parse_browse_page(html)

    assert first.slug == "pride-and-prejudice"
    assert first.title == "Pride and Prejudice"
    assert first.author == "Jane Austen"
    assert first.total_chapters == 61

    assert first.cover_image_url ==
             "https://chapter-summaries.com/static/images/covers/pride-and-prejudice.webp"
  end

  test "parse_chapters_page/1 extracts numbered chapter summaries" do
    html = File.read!(@chapters_fixture)

    assert {:ok, chapters} = ChapterSummaries.parse_chapters_page(html)
    assert map_size(chapters) == 2
    assert chapters[1] =~ "universally acknowledged"
    assert chapters[1] =~ "## Key Events"
    assert chapters[1] =~ "- Mr. Bingley arrives at Netherfield Park"
    assert chapters[1] =~ "## Characters Introduced"
    assert chapters[1] =~ "- Mr. Bingley"
    assert chapters[2] =~ "Mr. Bennet visits"
    refute chapters[2] =~ "## Key Events"
  end

  test "find_book/2 matches title and author from cached catalog" do
    assert %{slug: "pride-and-prejudice"} =
             Catalog.find_book("Pride and Prejudice", "Jane Austen")

    assert Catalog.find_book("Unknown Book", "Nobody") == nil
  end

  test "chapter_summaries_available?/2 reflects catalog membership" do
    assert Books.chapter_summaries_available?("1984", "George Orwell")
    refute Books.chapter_summaries_available?("Dune", "Frank Herbert")
  end

  test "resolve_slug/1 uses chapter_summaries_slug when set" do
    book = %Plotline.Books.Book{
      title: "Anything",
      author: "Anyone",
      chapter_summaries_slug: "pride-and-prejudice"
    }

    assert {:ok, "pride-and-prejudice"} = ChapterSummaries.resolve_slug(book)
  end

  test "add_book_with_summaries!/1 returns not_in_catalog for unknown books" do
    assert {:error, :not_in_catalog} =
             Books.add_book_with_summaries!(%{title: "Dune", author: "Frank Herbert"})
  end

  @tag :external
  test "live import for pride and prejudice" do
    Catalog.refresh!()

    assert {:ok, book, stats} =
             Books.add_book_with_summaries!(%{
               title: "Pride and Prejudice",
               author: "Jane Austen"
             })

    assert stats.imported == stats.total
    assert stats.total >= 61
    assert book.chapter_summaries_slug == "pride-and-prejudice"

    summaries = Plotline.Summaries.get_summaries_up_to(book.id, 2)
    assert length(summaries) == 2
  end
end
