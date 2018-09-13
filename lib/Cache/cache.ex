defmodule CommentServer.Cache do
  alias __MODULE__
  @tables %{}

  def set(object, key, category, expiration \\ nil) do
    entry =
      case expiration do
        nil -> {nil, object}
        value -> {cache_timestamp(), object}
      end

    load_or_create_table(category)
    |> :ets.insert({key, entry})

    object
  end

  def exists?(key, category) do
    case get(key, category) do
      nil -> false
      other -> true
    end
  end

  def clear(key, category), do: :ets.delete(category, key)

  def get_or_create(func, key, category, expiration \\ nil) do
    case get(key, category) do
      nil -> set(func.(), key, category)
      other -> other
    end
  end

  def get(key, category) do
    with table <- load_or_create_table(category) do
      case :ets.lookup(table, key) do
        # Todo: decide if this is the behavior we want.
        # We *shouldn't* have empty list results. They should always contain
        # something if the key has been initialized.
        [] ->
          nil

        [{expiration, object}] ->
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

  defp load_or_create_table(category) do
    case Map.get(@tables, category) do
      nil ->
        Map.put(
          @tables,
          category,
          :ets.new(category, [:named_table, :set, :public])
        )

      other ->
        other
    end
  end

  defp cache_timestamp(offset \\ 0), do: System.os_time(:second) + offset
end
