defmodule CommentServer.Cache do
  alias __MODULE__

  @cache_index :cache_index

  # todo: change this to use genserv

  def init(table_name) do
    case :ets.info(@cache_index) do
      :undefined -> :ets.new(@cache_index, [:named_table, :set, :public])
      _ -> @cache_index
    end

    case :ets.info(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :set, :public])
        :ets.insert(@cache_index, {table_name, true})
        :ok

      _ ->
        :ok
    end
  end

  def set(object, key, category, expiration \\ nil) do
    entry =
      case expiration do
        nil -> {nil, object}
        value -> {cache_timestamp(value), object}
      end

    check_category(category)
    |> :ets.insert({key, entry})

    object
  end

  def exists?(key, category) do
    case get(key, category) do
      nil -> false
      _other -> true
    end
  end

  def clear(key, category), do: :ets.delete(category, key)

  def get_or_create(func, key, category, expiration \\ nil) do
    case get(key, category) do
      nil -> set(func.(), key, category, expiration)
      other -> other
    end
  end

  def get(key, category) do
    with table <- check_category(category) do
      case :ets.lookup(table, key) do
        # Todo: decide if this is the behavior we want.
        # We *shouldn't* have empty list results. They should always contain
        # something if the key has been initialized.
        [] ->
          nil

        [{_key, {expiration, object}}] ->
          case expiration do
            # no expiration
            nil ->
              object

            value ->
              case value < cache_timestamp() do
                # we could delete the entry, but there's no point
                true ->
                  nil

                false ->
                  object
              end
          end
      end
    end
  end

  defp check_category(category) do
    case :ets.lookup(@cache_index, category) do
      [] -> raise ArgumentError, message: "Category #{inspect(category)} not initialized!"
      [{category, true}] -> category
    end
  end

  defp cache_timestamp(offset \\ 0), do: System.os_time(:second) + offset
end
