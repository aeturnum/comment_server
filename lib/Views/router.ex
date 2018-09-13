defmodule CommentServer.Views.Router do
  use Plug.Router

  plug(CORSPlug)
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> Plug.Conn.send_resp(200, "hi")
  end
end
