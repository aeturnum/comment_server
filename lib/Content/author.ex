defmodule CommentServer.Content.Author do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Domain
  alias CommentServer.Cache
  alias CommentServer.Util.H
  alias __MODULE__

  @table "authors"
  @cache_name :cache_authors
  @keys %{
    # id from rethinkdb
    db_id: "id",
    domain: "domain",
    domain_id: "domain_id",
    local_id: "local_id",
    name: "name",
    username: "username",
    total_posts: "total_posts",
    total_likes: "total_likes",
    location: "location",
    joined_at: "joined_at",
    profile_url: "profile_url"
  }
  @enforce_keys [:domain, :local_id]

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
            local_id: "",
            name: "",
            username: "",
            total_posts: 0,
            total_likes: 0,
            location: "",
            joined_at: "",
            profile_url: ""

  def create(args) do
    # check our arguments
    optional_keys = [
      :name,
      :username,
      :total_likes,
      :total_posts,
      :location,
      :joined_at,
      :profile_url
    ]

    defaults = [
      name: "",
      username: Keyword.get(args, :local_id, "none"),
      total_likes: 0,
      total_posts: 0,
      location: nil,
      joined_at: "",
      profile_url: ""
    ]

    with true <- Keyword.has_key?(args, :domain),
         true <- Keyword.has_key?(args, :local_id) do
      Enum.reduce(
        optional_keys,
        %Author{
          domain: Keyword.get(args, :domain),
          local_id: Keyword.get(args, :local_id)
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
    else
      _ -> nil
    end
  end

  def exists?(%Author{} = c), do: Operations.exists?(%{local_id: c.local_id}, @table)
  def exists?(l_id), do: Operations.exists?(%{local_id: l_id}, @table)

  def delete(%Author{db_id: "", local_id: local_id}),
    do: Operations.delete(%{local_id: local_id}, @table)

  def delete(%Author{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  def get_from_id("anon"), do: :anon
  def get_from_id(id), do: Operations.get(%{id: id}, @table) |> to_author
  def get_from_local_id(l_id), do: Operations.get(%{local_id: l_id}, @table) |> to_author

  def insert(author, need_db_id \\ false)
  # special case for :anon
  def insert(:anon, _), do: {:ok, :anon}

  def insert(author, need_db_id) do
    case exists?(author) do
      # todo: work on logic on when we force replacements
      true ->
        case need_db_id do
          true ->
            # TODO: Use cache to avoid this
            # need this now to include db_id
            result = get_from_local_id(author.local_id)
            H.debug("Avoided inserting duplicate author: #{inspect(author)}", result)
            {:ok, result}

          false ->
            H.debug(
              "Avoided inserting duplicate author and skipped dbid: #{inspect(author)}",
              author
            )

            {:ok, author}
        end

      false ->
        with {:ok, domain} <- Domain.insert(author.domain, true),
             author <- Map.put(author, :domain, domain) do
          author
          |> to_map
          |> Operations.put(@table)
          |> case do
            # todo: add cache
            {:ok, db_id} ->
              result = Map.put(author, :db_id, db_id)
              H.debug("Created new Author: #{inspect(result)}")
              # IO.puts("Created new Author: #{inspect(author)}")
              {:ok, result}

            other ->
              other
          end
        else
          other -> other
        end
    end
  end

  defp to_author({:ok, author_map}), do: to_author(author_map)

  defp to_author(author) do
    %Author{
      db_id: author[@keys.db_id],
      domain: Domain.get_from_id(author[@keys.domain_id]),
      local_id: author[@keys.local_id],
      name: author[@keys.name],
      username: author[@keys.username],
      total_posts: author[@keys.total_posts],
      total_likes: author[@keys.total_likes],
      location: author[@keys.location],
      joined_at: author[@keys.joined_at],
      profile_url: author[@keys.profile_url]
    }
  end

  defp to_map(a) do
    %{
      # We don't include the db_id here because that's managed by the DB.
      @keys.domain_id => a.domain.db_id,
      @keys.local_id => a.local_id,
      @keys.name => a.name,
      @keys.username => a.username,
      @keys.total_posts => a.total_posts,
      @keys.total_likes => a.total_likes,
      @keys.location => a.location,
      @keys.joined_at => a.joined_at,
      @keys.profile_url => a.profile_url
    }
  end
end
