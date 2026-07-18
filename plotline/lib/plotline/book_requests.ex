defmodule Plotline.BookRequests do
  @moduledoc """
  Stores user requests for books not yet available in the catalog.
  """

  import Ecto.Query, warn: false

  alias Plotline.BookRequests.BookRequest
  alias Plotline.Repo

  def create_request(user_id, attrs) when is_integer(user_id) do
    %BookRequest{user_id: user_id, status: "pending"}
    |> BookRequest.changeset(attrs)
    |> Repo.insert()
  end

  def list_pending_requests do
    Repo.all(from r in BookRequest, where: r.status == "pending", order_by: [desc: r.inserted_at])
  end

  def list_requests_for_user(user_id) do
    Repo.all(
      from r in BookRequest,
        where: r.user_id == ^user_id,
        order_by: [desc: r.inserted_at]
    )
  end
end
