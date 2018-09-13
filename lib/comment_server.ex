defmodule CommentServer do
  use Application

  def init(:ok) do
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # EtsCache.Cache.Core.init()

    children = [
      worker(CommentServer.Views.Cowboy, []),
      # todo: why do I need to nest this goddamn list?
      # Enum.map(list, fn {key, value} -> {:"#{key}", value} end)
      worker(CommentServer.Database.DBConnection, [
        Application.get_env(:comment_server, :database)
        |> Enum.map(fn {key, value} -> {:"#{key}", value} end)
      ])
    ]

    opts = [strategy: :one_for_one, name: CommentServer.Supervisor]
    Supervisor.start_link(children, opts)
    # HTTPoison.start()
  end
end
