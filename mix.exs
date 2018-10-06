defmodule CommentServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :comment_server,
      version: "0.1.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:cowboy, :ranch, :logger, :httpoison, :plug],
      mod: {CommentServer, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # JSON library
      # rethinkdb wants 1.5 or 2.0, but screw it
      {:poison, "~> 3.1", override: true},
      # HTTP request library that uses :poison
      {:httpoison, "~> 0.11"},
      # HTML Parsing library
      {:floki, "~> 0.20.0"},
      # webserver
      {:cowboy, "~> 2.0"},
      # modular HTTP library
      {:plug, "~> 1.3"},
      # test coverage
      {:excoveralls, "~> 0.4", only: :test},
      # CORS support
      {:cors_plug, "~> 1.1"},
      # rethink support
      # {:rethinkdb, "~> 0.4"}
      # use github branch with updates
      {:rethinkdb, github: "vaartis/rethinkdb-elixir", branch: "master"},
      # password hashing because we need accounts because the internet sucks
      {:comeonin, "~> 4.0"},
      # Argon support library
      {:argon2_elixir, "~> 1.2"},
      # UUID generator for session tokens
      {:elixir_uuid, "~> 1.2"},
      # mutex to avoid un-needed work
      {:mutex, "~> 1.0.0"}
    ]
  end
end
