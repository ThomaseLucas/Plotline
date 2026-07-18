defmodule Plotline.Pdf.TextExtractor.TestExtractor do
  @moduledoc false

  @sample """
  Frankenstein

  by Mary Shelley

  Chapter 1
  These are the opening events of the first chapter with enough text
  to pass the minimum chapter length requirement for the splitter path.

  Chapter 2
  The second chapter continues the story with more narrative content
  so the processor can generate a second AI summary entry in tests.
  """

  def extract(_path), do: {:ok, @sample}

  def binary_available?, do: true
end
