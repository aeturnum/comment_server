defmodule CommentServer.Util.H do
  @debug false

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
end
