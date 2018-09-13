defmodule CommentServer.Content.Article do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Domain
  alias __MODULE__

  @enforce_keys [:domain, :full_url]
  # we would like accesses to be a tuple, but that can't be represented in JSON so :'('
  defstruct db_id: "", domain: nil, full_url: nil, accesses: [], extra: %{}

  @table "articles"
  @keys %{
    # id from rethinkdb
    db_id: "id",
    domain: "domain",
    domain_id: "domain_id",
    full_url: "full_url",
    accesses: "accesses",
    extra: "extra"
  }

  def exists?(%Article{db_id: "", full_url: full_url}), do: host_path_exists(full_url)
  def exists?(%Article{db_id: db_id}), do: Operations.exists?(%{id: db_id}, @table)

  def exists?(url) do
    # %URI{scheme: "http", path: "/", query: nil, fragment: nil,
    #  authority: "elixir-lang.org", userinfo: nil,
    #  host: "elixir-lang.org", port: 80}
    host_path_exists(url)
  end

  def create(url) do
    with domain <- Domain.create(url) do
      %Article{domain: domain, full_url: url}
    end
  end

  def get_from_full_url(full_url), do: Operations.get(%{full_url: full_url}, @table) |> to_article
  def get_from_id(id), do: Operations.get(%{id: id}, @table) |> to_article

  def insert(article, need_db_id \\ false) do
    case exists?(article) do
      # todo: is this right?
      true ->
        case need_db_id do
          true ->
            # TODO: Use cache to avoid this
            # need this now to include db_id
            {:ok, get_from_full_url(article.full_url)}

          false ->
            {:ok, article}
        end

      false ->
        with {:ok, domain} <- Domain.insert(article.domain, true),
             article <- Map.put(article, :domain, domain) do
          case article |> to_map |> Operations.put(@table) do
            {:ok, db_id} ->
              {:ok, Map.put(article, :db_id, db_id)}

            other ->
              other
          end
        else
          other -> other
        end
    end
  end

  def delete(%Article{db_id: "", full_url: full_url}),
    do: Operations.delete(%{full_url: full_url}, @table)

  def delete(%Article{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  # defp host_exists(host), do: Operations.exists?(%{"host": host}, @table)
  defp host_path_exists(full_url), do: Operations.exists?(%{full_url: full_url}, @table)

  defp to_article(lst) when is_list(lst), do: Enum.map(lst, &to_article/1)

  defp to_article({:ok, domain_map}), do: to_article(domain_map)

  defp to_article(article) do
    %Article{
      db_id: article[@keys.db_id],
      domain: Domain.get_from_id(article[@keys.domain_id]),
      full_url: article[@keys.full_url],
      accesses: article[@keys.accesses],
      extra: article[@keys.extra]
    }
  end

  defp to_map(c) do
    %{
      @keys.domain_id => c.domain.db_id,
      @keys.full_url => c.full_url,
      @keys.accesses => c.accesses,
      @keys.extra => c.extra
    }
  end
end
