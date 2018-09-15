defmodule CommentServer.Content.Author do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Timestamp
  alias CommentServer.Util.H
  alias __MODULE__

  @table "authors"
  @cache_name :cache_authors
  @keys %{
    # id from rethinkdb
    db_id: "id",
    domain: "domain",
    domain_id: "domain_id",
    name: "name",
    username: "username",
    total_posts: "total_posts",
    total_likes: "total_likes",
    location: "location",
    joined_at: "joined_at",
    profile_url: "profile_url",
    updated: "updated"
  }
  # 20 minutes
  @stale_time 20 * 60
  @stale_units :second
  @enforce_keys [:domain, :username]

  # from python
  #  def user_info_row(self):
  #      return [
  #          self.id,
  #          self.name,
  #          self.username,
  #          self.total_posts,
  #          self.total_likes,
  #          self.location,
  #          self.joined_at,
  #          self.profile_url
  #      ]

  defstruct db_id: "",
            domain: nil,
            name: "",
            username: "",
            total_posts: 0,
            total_likes: 0,
            location: "",
            joined_at: "",
            profile_url: "",
            updated: Timestamp.new()

  def create(args) do
    # check our arguments
    optional_keys = [
      :name,
      :total_likes,
      :total_posts,
      :location,
      :joined_at,
      :profile_url
    ]

    defaults = [
      name: "",
      total_likes: 0,
      total_posts: 0,
      location: nil,
      joined_at: "",
      profile_url: ""
    ]

    with true <- Keyword.has_key?(args, :domain),
         true <- Keyword.has_key?(args, :username) do
      Enum.reduce(
        optional_keys,
        %Author{
          domain: Keyword.get(args, :domain),
          username: Keyword.get(args, :username),
          updated: Timestamp.new()
        },
        fn optional_key, comment ->
          Map.put(
            # add value
            comment,
            optional_key,
            Keyword.get(
              # key, if it exists in the optional keys
              args,
              optional_key,
              # default value
              Keyword.get(defaults, optional_key)
            )
          )
        end
      )
      |> H.pack(:ok)
    else
      _ -> {:error, nil}
    end
  end

  def exists?(%Author{username: username}), do: Operations.exists?(%{username: username}, @table)
  def exists?(username), do: Operations.exists?(%{username: username}, @table)

  def fresh?(d, get \\ false)

  def fresh?(:anon, get) do
    case get do
      true -> {true, :anon}
      false -> true
    end
  end

  def fresh?(%Author{username: username}, get), do: fresh?(username, get)

  def fresh?(username, get) do
    with {:ok, author} <- get_from_username(username),
         f <- fresh(author) do
      case get do
        true ->
          H.debug("Author.fresh?(#{username}) -> #{f}")
          {f, author}

        false ->
          H.debug("Author.fresh?(#{username}) -> #{f}")
          f
      end
    end
  end

  defp fresh(nil), do: false
  defp fresh(:anon), do: true
  defp fresh(%Author{updated: up}), do: Timestamp.within_range(up, @stale_time, @stale_units)

  def delete(%Author{db_id: "", username: username, domain: %Domain{db_id: dbid}}),
    do: Operations.delete(%{username: username, domain_id: dbid}, @table)

  def delete(%Author{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  def get_from_id("anon"), do: {:ok, :anon}
  def get_from_id(id), do: get_map(%{id: id})

  def get_from_username(username), do: get_map(%{username: username})

  def insert(author, need_db_id \\ false)
  # special case for :anon
  def insert(:anon, _), do: {:ok, :anon}

  def insert(author, need_db_id) do
    with {:ok, domain} <- Domain.insert_if_stale(author.domain),
         author <- Map.put(author, :domain, domain) do
      to_map(author)
      |> Operations.put(@table)
      |> case do
        # todo: add cache
        {:ok, db_id} ->
          result = Map.put(author, :db_id, db_id)
          H.debug("Inserted new Author: #{inspect(result)}")
          {:ok, result}

        other ->
          other
      end
    else
      other -> other
    end
  end

  def insert_if_stale(author) do
    case fresh?(author, true) do
      {true, author} ->
        H.debug("Author.insert_if_stale(#{inspect(author)}) -> fresh, returning existing")
        {:ok, author}

      {false, _} ->
        H.debug("Author.insert_if_stale(#{inspect(author)}) -> stale, inserting")
        insert(author)
    end
  end

  defp get_map(map) do
    case Operations.get(map, @table) do
      {:ok, []} -> {:ok, nil}
      {:ok, result} -> {:ok, to_author(result)}
      other -> other
    end
  end

  defp to_author({:ok, author_map}), do: to_author(author_map)

  defp to_author(author) do
    with {:ok, d} <- Domain.get_from_id(author[@keys.domain_id]) do
      %Author{
        db_id: author[@keys.db_id],
        domain: d,
        name: author[@keys.name],
        username: author[@keys.username],
        total_posts: author[@keys.total_posts],
        total_likes: author[@keys.total_likes],
        location: author[@keys.location],
        joined_at: author[@keys.joined_at],
        profile_url: author[@keys.profile_url],
        updated: Timestamp.from_db_format(author[@keys.updated])
      }
    end
  end

  defp to_map(a) do
    %{
      # We don't include the db_id here because that's managed by the DB.
      @keys.domain_id => a.domain.db_id,
      @keys.name => a.name,
      @keys.username => a.username,
      @keys.total_posts => a.total_posts,
      @keys.total_likes => a.total_likes,
      @keys.location => a.location,
      @keys.joined_at => a.joined_at,
      @keys.profile_url => a.profile_url,
      @keys.updated => Timestamp.to_db_format(a.updated)
    }
  end
end
