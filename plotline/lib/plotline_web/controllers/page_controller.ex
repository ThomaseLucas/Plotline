defmodule PlotlineWeb.PageController do
  use PlotlineWeb, :controller

  def home(conn, _params) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      redirect(conn, to: ~p"/library")
    else
      conn
      |> assign(:hide_nav, true)
      |> render(:home)
    end
  end
end
