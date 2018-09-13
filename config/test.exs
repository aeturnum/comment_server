use Mix.Config

config :comment_server,
  database: %{
    db: "comment_server_test",
    host: "127.0.0.1",
    port: 28015
  }