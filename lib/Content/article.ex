defmodule CommentServer.Content.Article do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Timestamp
  alias CommentServer.Util.H
  alias __MODULE__

  @stale_time 12 * 60 * 60
  @stale_units :second
  @enforce_keys [:domain, :full_url]
  # we would like accesses to be a tuple, but that can't be represented in JSON so :'('
  defstruct db_id: "",
            domain: nil,
            full_url: nil,
            accesses: [],
            extra: %{},
            updated: Timestamp.new()

  @table "articles"
  @keys %{
    # id from rethinkdb
    db_id: "id",
    domain: "domain",
    domain_id: "domain_id",
    full_url: "full_url",
    accesses: "accesses",
    extra: "extra",
    updated: "updated"
  }

  def exists?(%Article{db_id: "", full_url: full_url}), do: host_path_exists(full_url)
  def exists?(%Article{db_id: db_id}), do: Operations.exists?(%{id: db_id}, @table)

  def exists?(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    host_path_exists(url)
  end

  def fresh?(d, get \\ false)

  def fresh?(%Article{full_url: full_url}, get), do: fresh?(full_url, get)

  def fresh?(url, get) do
    with {:ok, article} <- get_from_full_url(url) do
      case get do
        true -> {fresh(article), article}
        false -> fresh(article)
      end
    end
  end

  defp fresh(nil), do: false
  defp fresh(%Article{updated: up}), do: Timestamp.within_range(up, @stale_time, @stale_units)

  def create(url) do
    with {:ok, domain} <- Domain.create(url) do
      {:ok, %Article{domain: domain, full_url: url, updated: Timestamp.new()}}
    end
  end

  def get_from_full_url(full_url), do: get_map(%{full_url: full_url})

  def get_from_id(id), do: get_map(%{id: id})

  def insert_if_stale(article) do
    case fresh?(article, true) do
      {true, article} -> {:ok, article}
      {false, _} -> insert(article)
    end
  end

  def insert(article) do
    with {:ok, domain} <- Domain.insert_if_stale(article.domain),
         article <- Map.put(article, :domain, domain) do
      case article |> to_map |> Operations.put(@table) do
        {:ok, db_id} ->
          {:ok, Map.put(article, :db_id, db_id)}

        other ->
          other
      end
    end
  end

  def delete(%Article{db_id: "", full_url: full_url}),
    do: Operations.delete(%{full_url: full_url}, @table)

  def delete(%Article{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  # defp host_exists(host), do: Operations.exists?(%{"host": host}, @table)
  defp host_path_exists(full_url), do: Operations.exists?(%{full_url: full_url}, @table)

  defp get_map(map) do
    case Operations.get(map, @table) do
      {:ok, []} -> {:ok, nil}
      {:ok, result} -> {:ok, to_article(result)}
      other -> other
    end
  end

  defp to_article(lst) when is_list(lst), do: Enum.map(lst, &to_article/1)

  defp to_article({:ok, domain_map}), do: to_article(domain_map)

  defp to_article(article) do
    with {:ok, d} <- Domain.get_from_id(article[@keys.domain_id]) do
      %Article{
        db_id: article[@keys.db_id],
        domain: d,
        full_url: article[@keys.full_url],
        accesses: article[@keys.accesses],
        extra: article[@keys.extra],
        updated: Timestamp.from_db_format(article[@keys.updated])
      }
    end
  end

  defp to_map(c) do
    %{
      @keys.domain_id => c.domain.db_id,
      @keys.full_url => c.full_url,
      @keys.accesses => c.accesses,
      @keys.extra => c.extra,
      @keys.updated => Timestamp.to_db_format(c.updated)
    }
  end
end
