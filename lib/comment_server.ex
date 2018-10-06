defmodule CommentServer do
  use Application

  def init(:ok) do
    CommentServer.Sync.init(:ok)
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # EtsCache.Cache.Core.init()

    children = [
      worker(CommentServer.Views.Cowboy, []),
      Mutex.child_spec(MyMutex),
      # todo: why do I need to nest this goddamn list?
      # Enum.map(list, fn {key, value} -> {:"#{key}", value} end)
      worker(CommentServer.Database.DBConnection, [
        Application.get_env(:comment_server, :database)
        |> Enum.map(fn {key, value} -> {:"#{key}", value} end)
      ])
    ]

    opts = [strategy: :one_for_one, name: CommentServer.Supervisor]
    Supervisor.start_link(children, opts)
    dispatch_config = CommentServer.HTTP.Router.build_dispatch_config()

    {:ok, _} =
      :cowboy.start_clear(
        # name, not important
        :http,
        # keyword args
        [{:port, 8081}],
        # environment
        %{env: %{dispatch: dispatch_config}}
      )
  end
end
