defmodule Plotline.CatalogSync do
  @moduledoc """
  Coordinates user-triggered catalog refreshes from chapter-summaries.com.

  Only one sync runs at a time, and callers are rate-limited to avoid hammering
  the external site when the reload button is clicked repeatedly.
  """

  use Agent

  alias Plotline.Extraction.Adapters.ChapterSummaries.Catalog

  def start_link(_opts) do
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  @doc """
  Starts an async catalog refresh when allowed.

  Returns `{:ok, :started}`, `{:error, :in_progress}`, or
  `{:error, {:rate_limited, seconds_remaining}}`.
  """
  def request_sync(caller_pid) when is_pid(caller_pid) do
    Agent.get_and_update(__MODULE__, fn state ->
      now = now_ms()

      cond do
        state.syncing ->
          {{:error, :in_progress}, state}

        state.last_finished_at == 0 ->
          start_sync(state, caller_pid)

        now - state.last_finished_at < cooldown_ms() ->
          remaining_ms = cooldown_ms() - (now - state.last_finished_at)
          seconds = remaining_ms |> div(1000) |> max(1)
          {{:error, {:rate_limited, seconds}}, state}

        true ->
          start_sync(state, caller_pid)
      end
    end)
  end

  defp start_sync(state, caller_pid) do
    Task.start(fn -> run_sync(caller_pid) end)
    {{:ok, :started}, %{state | syncing: true}}
  end

  @doc false
  def syncing? do
    Agent.get(__MODULE__, & &1.syncing)
  end

  defp run_sync(caller_pid) do
    result =
      try do
        books = Catalog.refresh!()
        {:ok, length(books)}
      catch
        kind, reason -> {:error, {kind, reason}}
      end

    Agent.update(__MODULE__, fn state ->
      %{state | syncing: false, last_finished_at: now_ms()}
    end)

    send(caller_pid, {:catalog_sync_done, result})
  end

  defp initial_state do
    %{syncing: false, last_finished_at: 0}
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp cooldown_ms do
    Application.get_env(:plotline, __MODULE__, [])
    |> Keyword.get(:cooldown_ms, :timer.seconds(30))
  end
end
