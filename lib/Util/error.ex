defmodule CommentServer.Util.Error do
  def new(error_string) do
    with {:current_stacktrace, trace} <- Process.info(self(), :current_stacktrace)
    do
      {:error, "Error: #{error_string}\nStacktrace:\n\t#{stacktrace_str(trace)}"}
    end
  end

  def handle(possible_error) do
    case possible_error do
      {:error, why} ->
        IO.puts(why)
        exit(:error)
      other -> other
    end
  end

  def ok?(possible_error) do
    case possible_error do
      {:error, why} ->
        IO.puts(why)
        exit(:error)
      {:ok, info} -> info
    end
  end

  defp stacktrace_str(trace) do
    trace
    |> Enum.drop(2) # first two entries are this function and Process
    |> Enum.map(&trace_entry_to_str/1)
    |> Enum.join("\n\t")
  end

  defp trace_entry_to_str({module, func_atom, arity, extras}) do
    "#{Keyword.get(extras, :file)}:#{Keyword.get(extras, :line)} | #{module_and_atom_str(module, func_atom, arity)}"
  end

  defp module_and_atom_str(module, atom, arity), do: "#{module_to_str(module)}.#{to_string(atom)}/#{arity}"

  defp module_to_str(module), do: "#{module}" |> String.split(".", parts: 2) |> Enum.at(1)
end