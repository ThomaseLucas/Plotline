defmodule Plotline.AI.TestProvider do
  @moduledoc false
  @behaviour Plotline.AI.Provider

  @impl true
  def generate(system_instruction, user_message) do
    cond do
      String.contains?(system_instruction, "--- Chapter 3 ---") ->
        {:error, :test_failure}

      String.contains?(system_instruction, "Respond with JSON only") ->
        numbers =
          Regex.scan(~r/===== CHAPTER (\d+):/, user_message)
          |> Enum.map(fn [_, n] -> String.to_integer(n) end)

        payload =
          Enum.map(numbers, fn n ->
            %{
              "chapter_number" => n,
              "summary_text" =>
                "Summary for chapter #{n}.\n\n## Key Events\n- Event\n\n## Characters\n- Someone — role\n\n## Themes\n- theme"
            }
          end)

        {:ok, Jason.encode!(payload)}

      String.contains?(system_instruction, "chapter summaries for Plotline") ->
        {:ok,
         """
         A short prose summary of the chapter events.

         ## Key Events
         - An important event happens

         ## Characters
         - Protagonist — present in this chapter

         ## Themes
         - discovery
         """}

      true ->
        {:ok, "Test assistant reply to: #{user_message}"}
    end
  end
end
