defmodule Plotline.CatalogSyncTest do
  use Plotline.DataCase, async: false

  alias Plotline.CatalogSync

  setup do
    on_exit(fn ->
      Application.put_env(:plotline, Plotline.CatalogSync, cooldown_ms: 0)
    end)

    :ok
  end

  test "returns in_progress when a sync is already running" do
    Agent.update(CatalogSync, fn _ -> %{syncing: true, last_finished_at: 0} end)
    on_exit(fn -> Agent.update(CatalogSync, fn _ -> %{syncing: false, last_finished_at: 0} end) end)

    assert {:error, :in_progress} = CatalogSync.request_sync(self())
  end

  test "returns rate_limited within the cooldown window" do
    Application.put_env(:plotline, Plotline.CatalogSync, cooldown_ms: 60_000)

    Agent.update(CatalogSync, fn _ ->
      %{syncing: false, last_finished_at: System.monotonic_time(:millisecond)}
    end)

    assert {:error, {:rate_limited, seconds}} = CatalogSync.request_sync(self())
    assert seconds > 0
  end
end
