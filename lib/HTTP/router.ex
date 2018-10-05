defmodule CommentServer.HTTP.Router do
  use Plug.Router
  use Plug.Builder
  alias CommentServer.Util.H
  alias CommentServer.HTTP.Routes
  alias CommentServer.Admin.SystemUser

  def build_dispatch_config() do
    :cowboy_router.compile([
      {:_,
       [
         # {"/", :cowboy_static, {:priv_file, :comment_server, "index.html"}},
         {"/static/[...]", :cowboy_static, {:dir, :comment_server, "static"}},
         {"/status", WebsocketHandler, []},
         {:_, Plug.Adapters.Cowboy2.Handler, {CommentServer.HTTP.Router, []}}
       ]}
    ])
  end

  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:match)
  plug(:dispatch)

  get("/", do: Routes.home(load_data(conn)))
  post("/login", do: Routes.login(load_data(conn)))
  post("/logout", do: Routes.logout(load_data(conn)))
  post("/create/:username", do: Routes.create_user(load_data(conn)))
  get(":_any", do: Plug.Conn.send_resp(conn, 404, "Not Found"))

  defp load_data(conn), do: conn |> Plug.Conn.fetch_cookies() |> load_user() |> json_parse()

  defp load_user(conn = %{cookies: %{"session" => s}}) do
    IO.puts("load user with session #{s}")
    Map.put(conn, :user, SystemUser.load_session(s) |> IO.inspect())
  end

  defp load_user(conn = %{cookies: _}), do: Map.put(conn, :user, nil)

  defp json_parse(conn) do
    conn
    |> Map.put(:body_params, H.replace_known_keys(Map.get(conn, :body_params)))
    |> Map.put(:params, H.replace_known_keys(Map.get(conn, :params)))
  end
end
