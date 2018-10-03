defmodule CommentServer.HTTP.Router do
  use Plug.Router
  use Plug.Builder
  alias CommentServer.Util.H
  alias CommentServer.HTTP.Routes
  alias CommentServer.Admin.SystemUser

  def build_dispatch_config() do
    # _: [
    #   {"/scripts/[...]", :cowboy_static, {:dir, "../sabaki_server/priv/scripts"}},
    #   {"/css/[...]", :cowboy_static, {:dir, "../sabaki_server/priv/css"}},
    #   {"/images/[...]", :cowboy_static, {:dir, "../sabaki_server/priv/images"}},
    #   {"/topic", SabakiServer.HTTP.EchoController, [] },
    #   {:_, Plug.Adapters.Cowboy.Handler, {SabakiServer.HTTP.Router, []}}
    # ]
    :cowboy_router.compile([
      {:_,
       [
         {"/", :cowboy_static, {:priv_file, :comment_server, "index.html"}},
         {"/static/[...]", :cowboy_static, {:dir, :comment_server, "static"}},
         {"/status", WebsocketHandler, []},
         {:_, Plug.Adapters.Cowboy2.Handler, {CommentServer.HTTP.Router, []}}
       ]}
    ])
  end

  plug(:match)
  plug(:dispatch)

  post("/login", do: Routes.login(load_data(conn)))
  post("/create/:username", do: Routes.create_user(load_data(conn)))
  get(":_any", do: Plug.Conn.send_resp(conn, 404, "Not Found"))

  defp load_data(conn), do: conn |> Plug.Conn.fetch_cookies() |> load_user() |> json_parse()

  defp load_user(conn = %{cookies: %{"session" => s}}) do
    Map.put(conn, :user, SystemUser.load_session(s))
  end

  defp load_user(conn = %{cookies: _}), do: Map.put(conn, :user, nil)

  defp json_parse(conn) do
    conn =
      Plug.Parsers.call(
        conn,
        Plug.Parsers.init(parsers: [Plug.Parsers.JSON], pass: ["*/*"], json_decoder: Poison)
      )

    conn
    |> Map.put(:body_params, H.replace_known_keys(Map.get(conn, :body_params)))
    |> Map.put(:params, H.replace_known_keys(Map.get(conn, :params)))
  end
end
