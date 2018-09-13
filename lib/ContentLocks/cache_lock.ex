defmodule CommentServer.ContentLocks do
  alias CommentServer.Cache
  alias __MODULE__

  @table_name "content_locks"

  def author_locked?(identifier) do
    Cache.exists?(author_key(identifier), @table_name)
  end

  def author_lock(identifier, wait \\ 30) do
    Cache.set(true, author_key(identifier), @table_name)
  end

  def author_unlock(identifier), do: Cache.clear(author_key(identifier), @table_name)

  defp author_key(id), do: "author_" <> inspect(id)
end
