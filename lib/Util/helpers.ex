defmodule CommentServer.Util.H do
  @debug false

  def as_list(i) when is_list(i), do: i
  def as_list(i), do: [i]

  def pack(result, atom), do: {atom, result}

  def pack_if(t = {}, true, object), do: Tuple.append(t, object)
  def pack_if(t = {}, false, _object), do: t
  def pack_if(non_tuple, true, object), do: {non_tuple, object}
  def pack_if(non_tuple, false, _object), do: non_tuple

  def debug(line, object \\ []) do
    case @debug do
      true ->
        IO.puts(line)
        dprint(object)

      false ->
        :ok
    end
  end

  defp dprint([object | rest]) do
    IO.inspect(object)
    dprint(rest)
  end

  defp dprint([]), do: :ok

  defp dprint(object), do: IO.inspect(object)

  @known_keys %{
    "username" => :username,
    "password" => :password
  }

  def replace_known_keys(map) do
    Enum.reduce(Map.keys(@known_keys), map, fn swap_key, map ->
      case Map.has_key?(map, swap_key) do
        true ->
          map
          |> Map.put(@known_keys[swap_key], map[swap_key])
          |> Map.delete(swap_key)

        false ->
          map
      end
    end)
  end
end
