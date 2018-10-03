defmodule Mix.Tasks.Server do
  use Mix.Task

  # @shortdoc "Runs Server"
  @recursive true

  def run(args) do
    # opts = OptionParser.parse(args, aliases: [h: :host, p: :port]) |> elem(0)
    # start is called implicitly by this
    Mix.Task.run("app.start", args)

    CommentServer.Database.Operations.setup_tables()
    CommentServer.Admin.SystemUser.setup_users()

    unless (Code.ensure_loaded?(IEx) && IEx.started?()) ||
             Code.ensure_loaded?(Mix.Tasks.ServerTest) do
      :timer.sleep(:infinity)
    end
  end

  def binary_to_integer(port) do
    case Integer.parse(port) do
      :error -> nil
      {i, _} -> i
    end
  end
end
