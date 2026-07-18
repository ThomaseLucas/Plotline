defmodule Plotline.HardcoverTest do
  use ExUnit.Case, async: true

  alias Plotline.Hardcover

  test "best_match/1 returns enriched metadata via test client" do
    hit = Hardcover.best_match("Frankenstein")

    assert hit.title == "Frankenstein"
    assert hit.author == "Mary Shelley"
    assert hit.hardcover_id == "hc-frankenstein"
  end

  test "best_match/1 returns nil when no hits" do
    assert Hardcover.best_match("zzzz-unknown-title") == nil
  end
end
