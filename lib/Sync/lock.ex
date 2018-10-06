defmodule CommentServer.Sync do
  alias CommentServer.Cache
  alias __MODULE__

  @table :locks

  def init(:ok) do
    Cache.init(@table)
  end

  def lock(key) do
    lock_put(Mutex.await(MyMutex, key), key)
  end

  def try_to_lock(key) do
    case Mutex.lock(MyMutex, key) do
      {:ok, lock} ->
        lock_put(lock, key)
        true

      {:error, _} ->
        false
    end
  end

  def unlock(key) do
    case lock_remove(key) do
      nil ->
        :ok

      lock ->
        Mutex.release(MyMutex, lock)
    end
  end

  defp lock_put(lock, key) do
    with local_key <- self() do
      Mutex.under(MyMutex, local_key, fn ->
        case Cache.get(local_key, @table) do
          nil -> %{key => lock}
          lock_map_for_pid -> Map.put(lock_map_for_pid, key, lock)
        end
        |> Cache.set(local_key, @table)

        :ok
      end)
    end
  end

  defp lock_remove(key) do
    with local_key <- self() do
      Mutex.under(MyMutex, local_key, fn ->
        case Cache.get(local_key, @table) do
          nil ->
            nil

          lock_map_for_pid ->
            # remove this from the shared map while we're locked
            Map.delete(lock_map_for_pid, key)
            |> Cache.set(local_key, @table)

            Map.get(lock_map_for_pid, key, nil)
        end
      end)
    end
  end
end
