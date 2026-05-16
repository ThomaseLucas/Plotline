defmodule PlotlineWeb.PageController do
  use PlotlineWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
