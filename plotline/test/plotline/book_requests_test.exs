defmodule Plotline.BookRequestsTest do
  use Plotline.DataCase, async: true

  alias Plotline.BookRequests
  alias Plotline.BookRequests.BookRequest

  import Plotline.AccountsFixtures

  test "create_request/2 with valid data stores a pending request" do
    user = user_fixture()

    assert {:ok, %BookRequest{} = request} =
             BookRequests.create_request(user.id, %{
               "title" => "Dune",
               "author" => "Frank Herbert",
               "notes" => "First book in the series"
             })

    assert request.user_id == user.id
    assert request.title == "Dune"
    assert request.author == "Frank Herbert"
    assert request.notes == "First book in the series"
    assert request.status == "pending"
  end

  test "create_request/2 rejects missing title" do
    user = user_fixture()

    assert {:error, changeset} =
             BookRequests.create_request(user.id, %{"title" => "", "author" => "Author"})

    assert "can't be blank" in errors_on(changeset).title
  end

  test "list_requests_for_user/1 returns only that user's requests" do
    user = user_fixture()
    other = user_fixture()

    {:ok, _} = BookRequests.create_request(user.id, %{"title" => "Book A", "author" => "Author A"})
    {:ok, _} = BookRequests.create_request(other.id, %{"title" => "Book B", "author" => "Author B"})

    assert [%BookRequest{title: "Book A"}] = BookRequests.list_requests_for_user(user.id)
  end
end
