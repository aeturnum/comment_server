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

  def fresh?(d, get \\ false)

  def fresh?(%Domain{host: host}, get) do
    # IO.puts("fresh?(#{inspect(host)}, #{get})")

    with {:ok, domain} <- get_from_host(host) do
      case get do
        true -> {domain != nil, domain}
        false -> domain != nil
      end
    end
  end

  def fresh?(url, get) do
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host),
         {:ok, domain} <- get_from_host(host) do
      case get do
        true -> {domain != nil, domain}
        false -> domain != nil
      end
    end
  end

  def create(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    with uri <- URI.parse(url),
         host <- Map.get(uri, :host) do
      {:ok, %Domain{host: host}}
    end
  end

  def get_from_host(host), do: get_map(%{host: host})

  def get_from_id(id), do: get_map(%{id: id})

  def create_in_db_or_get(url) do
    with domain <- create(url),
         {:ok, old_domain} <- get_from_host(domain.host) do
      case old_domain do
        nil -> insert(domain)
        _ -> {:ok, old_domain}
      end
    end
  end

  def insert_if_stale(domain) do
    case fresh?(domain, true) do
      {true, domain} -> {:ok, domain}
      {false, _} -> insert(domain)
    end
  end

  def insert(domain) do
    case domain |> to_map |> Operations.put(@table) do
      {:ok, db_id} ->
        {:ok, Map.put(domain, :db_id, db_id)}

      other ->
        other
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
      {:ok, []} -> {:ok, nil}
      {:ok, result} -> {:ok, to_domain(result)}
      other -> other
    end
  end

  defp to_domain(lst) when is_list(lst), do: Enum.map(lst, &to_domain/1)

  defp to_domain({:ok, domain_map}), do: to_domain(domain_map)

  defp to_domain(domain) do
    # IO.puts("to_domain(#{inspect(domain)})")

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
