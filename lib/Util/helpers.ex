defmodule CommentServer.Util.H do
  @debug false

  def pack(result, atom), do: {atom, result}

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
