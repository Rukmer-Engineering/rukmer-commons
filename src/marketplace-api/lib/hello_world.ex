defmodule HelloWorld do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "<h1>Hello World from Elixir!</h1><p>Rukmer Commons Deployment Test</p>")
  end

  get "/health" do
    send_resp(conn, 200, ~s({"status": "healthy", "service": "rukmer-app"}))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
