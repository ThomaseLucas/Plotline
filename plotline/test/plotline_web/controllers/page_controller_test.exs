defmodule PlotlineWeb.PageControllerTest do
  use PlotlineWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome Readers!"
    assert html_response(conn, 200) =~ "Stop forgetting where you left off"
    assert html_response(conn, 200) =~ "landing-loops-decoration"
  end
end
