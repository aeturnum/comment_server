defmodule CommentServer.Content.Domain do
  alias CommentServer.Database.Operations
  alias __MODULE__

  @enforce_keys [:host]
  # we would like accesses to be a tuple, but that can't be represented in JSON so :'('
  defstruct db_id: "", host: nil

  @table "domains"
  @keys %{
    # id from rethinkdb
    db_id: "id",
    host: "host"
  }

  defimpl String.Chars, for: Domain do
    def to_string(d), do: "#{inspect(d)}"
  end

  def exists?(d = %Domain{}) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    host_path_exists(d.host)
  end

  def exists?(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host) do
      host_path_exists(host)
    end
  end

  def fresh?(%Domain{host: host}) do
    case get_from_host(host) do
      {:ok, domain} -> true
      _ -> false
    end
  end

  def fresh?(url) do
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host),
         {:ok, domain} <- get_from_host(host) do
      case domain do
        nil -> false
        _ -> true
      end
    end
  end

  def create_if_new(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host) do
      %Domain{host: host}
    end
  end

  def create(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host) do
      %Domain{host: host}
    end
  end

  def get_from_host(host), do: get_map(%{host: host})

  def get_from_id(id), do: get_map(%{id: id})

  def insert(domain, need_db_id \\ false) do
    case exists?(domain) do
      # todo: is this right?
      true ->
        case need_db_id do
          true ->
            # TODO: Use cache to avoid this
            # need this now to include db_id
            {:ok, get_from_host(domain.host)}

          false ->
            {:ok, domain}
        end

      false ->
        case domain |> to_map |> Operations.put(@table) do
          {:ok, db_id} ->
            {:ok, Map.put(domain, :db_id, db_id)}

          other ->
            other
        end
    end
  end

  def delete(%Domain{db_id: "", host: host}),
    do: Operations.delete(%{host: host}, @table)

  def delete(%Domain{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  # defp host_exists(host), do: Operations.exists?(%{"host": host}, @table)
  defp host_path_exists(host) do
    Operations.exists?(%{host: host}, @table)
  end

  defp get_map(map) do
    case Operations.get(map, @table) do
      {:ok, []} -> nil
      {:ok, result} -> to_domain(result)
      other -> other
    end
  end

  defp to_domain(lst) when is_list(lst), do: Enum.map(lst, &to_domain/1)

  defp to_domain({:ok, domain_map}), do: to_domain(domain_map)

  defp to_domain(domain) do
    IO.puts("to_domain(#{inspect(domain)})")

    %Domain{
      db_id: domain[@keys.db_id],
      host: domain[@keys.host]
    }
  end

  defp to_map(c) do
    %{
      @keys.host => c.host
    }
  end
end
