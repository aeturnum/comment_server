defmodule CommentServer.Views.Cowboy do
  def start_link do
    Plug.Adapters.Cowboy2.http(
      CommentServer.Views.Router,
      [],
      port: 4000
    )
  end
end
