defmodule SprinkleWeb.PageController do
  use SprinkleWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end