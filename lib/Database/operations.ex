defmodule CommentServer.Database.Operations do
  alias RethinkDB.Query
  alias CommentServer.Database.DBConnection
  alias CommentServer.Util.Error
  alias CommentServer.Util.H

  @database Application.get_env(:comment_server, :database).db
  @system_tables ["users", "comments", "domains", "authors", "articles"]

  def exists?(id, table_name) when is_binary(id) do
    Query.table(table_name)
    |> Query.filter(%{id: id})
    |> result_exists
  end

  def exists?(map, table_name) when is_map(map) do
    result =
      Query.table(table_name)
      |> Query.filter(map)
      |> result_exists

    H.debug("exists.map? #{table_name}.#{inspect(map)} -> #{result}")
    result
  end

  def count(pattern, table_name) do
    Query.table(table_name)
    |> Query.filter(pattern)
    |> Query.count()
    |> run()
  end

  def get(pattern, table_name) do
    Query.table(table_name)
    |> Query.filter(pattern)
    |> run()
  end

  def delete(pattern, table_name) do
    case do_delete(pattern, table_name) do
      {:ok, result = %{"deleted" => count}} ->
        case count do
          0 ->
            Error.new(
              "Delete of #{inspect(pattern)} failed! \nresponse: #{inspect(result)} \n items: #{
                inspect(Query.table(table_name) |> run())
              }"
            )

          _ ->
            :ok
        end

      result ->
        Error.new(
          "Delete of #{inspect(pattern)} failed! \nresponse: #{inspect(result)} \n items: #{
            inspect(Query.table(table_name) |> run())
          }"
        )
    end
  end

  defp do_delete(pattern, table_name) do
    result =
      Query.table(table_name)
      |> Query.filter(pattern)
      |> Query.delete()
      |> run()

    H.debug("delete #{table_name}.#{inspect(pattern)} -> #{inspect(result)}")
    result
  end

  def put(map_of_values, table_name) do
    # IO.puts("putting to db: #{inspect(map_of_values)}")

    Query.table(table_name)
    |> Query.insert(map_of_values)
    |> run
    # strip :ok container
    |> Error.ok?()
    # get keys
    |> Map.get("generated_keys")
    # return generated key
    |> Enum.at(0)
    |> H.pack(:ok)
  end

  def setup_tables() do
    with :ok <- init_database(),
         {:ok, current_tables} <- table_names() do
      @system_tables
      |> Enum.filter(fn table -> !Enum.member?(current_tables, table) end)
      |> Enum.each(fn table -> create_table(table) end)
    else
      x -> Error.handle(x)
    end
  end

  def drop_tables() do
    with {:ok, names} <- table_names() do
      Enum.each(names, &drop_table/1)
    else
      x -> Error.handle(x)
    end
  end

  defp init_database() do
    with {:ok, dbs} <- list_databases() do
      case Enum.member?(dbs, @database) do
        true -> :ok
        false -> create_database()
      end
    end
  end

  defp result_exists(query) do
    query
    |> Query.count()
    |> run()
    |> Error.ok?()
    |> case do
      0 -> false
      _ -> true
    end
  end

  defp table_names(), do: Query.table_list() |> run() |> Error.handle()
  defp list_databases(), do: Query.db_list() |> run()
  defp create_database(), do: Query.db_create(@database) |> run()

  defp create_table(table_name) do
    # IO.puts("create_table #{table_name}")
    Query.table_create(table_name) |> run()
  end

  defp drop_table(table_name) do
    # IO.puts("dropping table #{table_name}")
    Query.table_drop(table_name) |> run()
  end

  defp run(operation) do
    operation
    |> DBConnection.run()
    |> case do
      {:ok, data} ->
        {:ok, eat_rethink_obj(data)}

      {:error, %RethinkDB.Response{data: data}} ->
        Error.new(Map.get(data, "r"))

      %RethinkDB.Exception.ConnectionClosed{} ->
        Error.new("RethinkDB #{db_info_str()} not running")
    end
  end

  defp db_info_str do
    with info <- Application.get_env(:comment_server, :database) do
      "#{info.host}:#{info.port}[#{info.db}]"
    end
  end

  # defp eat_rethink_obj(r = %RethinkDB.Response{data: data}) when @debug do
  #   IO.inspect r
  #   data
  # end
  # defp eat_rethink_obj(r = %RethinkDB.Record{data: data}) when @debug do
  #   IO.inspect r
  #   data
  # end
  # defp eat_rethink_obj(r = %RethinkDB.Collection{data: data}) when @debug do
  #   IO.inspect r
  #   data
  # end

  defp eat_rethink_obj(%RethinkDB.Response{data: data}), do: data
  defp eat_rethink_obj(%RethinkDB.Record{data: data}), do: data

  defp eat_rethink_obj(%RethinkDB.Collection{data: data = [first | _]})
       when is_list(data) and length(data) == 1,
       do: first

  defp eat_rethink_obj(%RethinkDB.Collection{data: data}), do: data
end
