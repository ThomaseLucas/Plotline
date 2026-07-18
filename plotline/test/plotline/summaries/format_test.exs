defmodule Plotline.Summaries.FormatTest do
  use ExUnit.Case, async: true

  alias Plotline.Summaries.Format

  test "parses structured summary with key events list" do
    text = """
    First paragraph about the chapter.

    Second paragraph continues.

    ## Key Events
    - Event one happens.
    - Event two follows.

    ## Themes
    - Friendship
    """

    sections = Format.to_sections(text)

    assert [%{title: nil, paragraphs: [p1, p2], items: []}, events, themes] = sections
    assert p1 =~ "First paragraph"
    assert p2 =~ "Second paragraph"
    assert events.title == "Key Events"
    assert events.items == ["Event one happens.", "Event two follows."]
    assert themes.title == "Themes"
    assert themes.items == ["Friendship"]
  end

  test "repairs legacy mashed key-events text" do
    text =
      "Vis runs ahead. ccccccKey Events Vis escapes through a tunnel. Caeror explains they are in Obiteum."

    sections = Format.to_sections(text)
    prose = Enum.find(sections, &is_nil(&1.title))
    events = Enum.find(sections, &(&1.title == "Key Events"))

    assert prose.paragraphs == ["Vis runs ahead."]
    assert length(events.items) == 2
    assert hd(events.items) =~ "Vis escapes"
  end

  test "normalizes assistant markdown bullets with bold labels" do
    text = """
    Based on the chapters you have read so far, here is what we know about Eo:

    *   **Relationship with Darrow:** She is Darrow’s wife.
    *   **Target of Oppression:** The Grays taunted Darrow about her.
    """

    sections = Format.to_sections(text)

    assert Enum.any?(sections, &(&1.title == "Relationship with Darrow"))
    assert Enum.any?(sections, &(&1.title == "Target of Oppression"))

    relationship = Enum.find(sections, &(&1.title == "Relationship with Darrow"))
    assert hd(relationship.paragraphs) =~ "Darrow’s wife"
    refute Enum.any?(sections, fn s -> Enum.any?(s.paragraphs, &String.contains?(&1, "**")) end)
  end
end
