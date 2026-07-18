defmodule Plotline.Pdf.ChapterSplitterTest do
  use ExUnit.Case, async: true

  alias Plotline.Pdf.ChapterSplitter

  test "splits on Chapter headings" do
    text = """
    Preface material here that is ignored once chapters start.

    Chapter 1
    #{String.duplicate("Alpha content. ", 20)}

    Chapter 2
    #{String.duplicate("Beta content. ", 20)}
    """

    chapters = ChapterSplitter.split(text)

    assert length(chapters) == 2
    assert Enum.map(chapters, & &1.number) == [1, 2]
    assert hd(chapters).text =~ "Alpha"
    assert List.last(chapters).text =~ "Beta"
  end

  test "splits on roman numeral chapters" do
    text = """
    Chapter I
    #{String.duplicate("First. ", 20)}

    Chapter II
    #{String.duplicate("Second. ", 20)}
    """

    chapters = ChapterSplitter.split(text)
    assert length(chapters) == 2
    assert hd(chapters).title =~ "Chapter 1"
  end

  test "falls back to chunks when no headings" do
    text = String.duplicate("plain narrative without headings. ", 200)
    chapters = ChapterSplitter.split(text)

    assert length(chapters) >= 2
    assert Enum.all?(chapters, &(&1.text != ""))
  end

  test "guess_title prefers early title-like line" do
    text = """
    Frankenstein

    or, The Modern Prometheus

    Chapter 1
    Something happens.
    """

    assert ChapterSplitter.guess_title(text, "Fallback") == "Frankenstein"
  end
end
