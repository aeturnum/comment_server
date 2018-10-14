defmodule CommentServer.Content.Comment do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Article
  alias CommentServer.Content.CommentVersion
  alias CommentServer.Content.Author
  alias CommentServer.Content.Timestamp
  alias CommentServer.Util.H
  alias CommentServer.Sync
  alias __MODULE__

  @table "comments"
  @mutext_prefix "mutex_comment_"
  # @cache_name :cache_comments
  @keys %{
    # id from rethinkdb
    db_id: "id",
    article: "article",
    article_id: "article_id",
    author: "author",
    author_id: "author_id",
    parent_id: "parent_id",
    local_id: "local_id",
    versions: "versions",
    message: "message",
    likes: "likes",
    deleted: "deleted",
    updated: "updated"
  }
  @stale_time 30 * 60
  @stale_units :second
  # from python code
  # row = [comment['id'], user.id, req_info.thread, comment['parent'], comment['thread']]
  # row.extend([comment['createdAt'], comment['raw_message'], comment['likes']])
  @enforce_keys [:article, :local_id, :versions]

  defimpl String.Chars, for: Comment do
    def to_string(%{db_id: db_id, local_id: lid, versions: v, updated: u}) do
      "%Comment{id: #{db_id}, l_id: #{lid}, versions[#{length(v)}]: [#{List.first(v)}|...], updated: #{
        u
      })"
    end
  end

  defstruct db_id: "",
            lock: 0,
            article: nil,
            local_id: nil,
            author: :anon,
            likes: 0,
            parent_id: nil,
            versions: [],
            updated: Timestamp.now()

  def create(args) do
    # check our arguments
    optional_keys = [:author, :parent_id, :likes]
    defaults = [author: :anon, parent_id: nil, likes: 0]

    with true <- Keyword.has_key?(args, :article),
         true <- Keyword.has_key?(args, :local_id),
         true <- Keyword.has_key?(args, :message),
         {:ok, version} <- CommentVersion.create(args) do
      Enum.reduce(
        optional_keys,
        %Comment{
          article: Keyword.get(args, :article),
          local_id: Keyword.get(args, :local_id),
          versions: [version],
          updated: version.updated
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

  def exists?(%Comment{} = c), do: Operations.exists?(%{local_id: c.local_id}, @table)
  def exists?(l_id), do: Operations.exists?(%{local_id: l_id}, @table)

  def fresh?(comment_or_local_id, get \\ false) do
    with {:ok, old_comment} <- get_from_local_id(comment_or_local_id),
         f <- fresh(old_comment) do
      H.debug("Comment.fresh?(#{comment_or_local_id}) -> #{f}")
      H.pack_if(f, get, old_comment)
    end
  end

  defp fresh(nil), do: false
  defp fresh(c), do: Timestamp.within_range(c.updated, @stale_time, @stale_units)

  defp pick_action(new_comment, nil), do: {:insert, new_comment}

  defp pick_action(%Comment{versions: [new_v]}, existing_comment = %Comment{}) do
    with {do_change, versions, updated} <-
           CommentVersion.add_if_changed(new_v, existing_comment.versions),
         refreshed_comment <- Map.put(existing_comment, :updated, updated) do
      case do_change do
        false ->
          case fresh(existing_comment) do
            true -> {:none, existing_comment}
            false -> {:update, refreshed_comment}
          end

        true ->
          {:update, Map.put(refreshed_comment, :versions, versions)}
      end
    end
  end

  def get_from_local_id(c = %Comment{local_id: l_id}) do
    c = check_lock(c)

    try do
      get_map(%{local_id: l_id})
    after
      unlock(c)
    end
  end

  def get_from_local_id(l_id), do: get_map(%{local_id: l_id})

  # todo: insert domain if needed
  def insert(comment) do
    with {:ok, article} <- Article.insert_if_stale(comment.article),
         {:ok, author} <- Author.insert_if_stale(comment.author),
         comment <- Map.put(comment, :article, article),
         comment <- Map.put(comment, :author, author) do
      comment
      |> to_map
      |> Operations.put(@table)
      |> case do
        # todo: add cache
        {:ok, db_id} ->
          result = Map.put(comment, :db_id, db_id)
          H.debug("Inserted new Comment: #{result}")
          {:ok, result}

        other ->
          H.debug("Insert of Comment failed: #{comment} ! #{inspect(other)}")
          other
      end
    else
      other -> other
    end
  end

  def update(comment) do
    H.debug("Comment.update(#{comment})")

    comment
    |> to_map
    |> Operations.update(comment, @table)

    {:ok, comment}
  end

  def insert_or_update(comment) do
    comment = check_lock(comment)

    try do
      with {:ok, old_comment} <- get_from_local_id(comment) do
        case pick_action(comment, old_comment) do
          {:none, fresh_comment} ->
            H.debug("Comment.insert_or_update(#{comment}) -> none")
            {:ok, fresh_comment}

          {:insert, fresh_comment} ->
            H.debug("Comment.insert_or_update(#{comment}) -> insert")
            insert(fresh_comment)

          {:update, fresh_comment} ->
            H.debug("Comment.insert_or_update(#{comment}) -> update")
            update(fresh_comment)
        end
      end
    after
      unlock(comment)
    end
  end

  def delete(%Comment{db_id: "", local_id: local_id, article: %Article{db_id: dbid}}),
    do: Operations.delete(%{local_id: local_id, article_id: dbid}, @table)

  def delete(%Comment{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  defp primary_key(%Comment{} = comment), do: comment.local_id
  defp primary_key(comment), do: Map.fetch!(comment, @keys.local_id)

  defp get_map(map) do
    case Operations.get(map, @table) do
      {:ok, []} -> {:ok, nil}
      {:ok, result} -> {:ok, to_comment(result)}
      other -> other
    end
  end

  defp check_lock(a = %Comment{lock: l}) when l > 0, do: %{a | lock: l + 1}

  defp check_lock(a = %Comment{lock: 0}) do
    Sync.lock(mutex_key(a))
    %{a | lock: 1}
  end

  defp unlock(a = %Comment{lock: l}) when l < 2 do
    # we can 'unlock' a non-locked author
    Sync.unlock(mutex_key(a))
    %{a | lock: 0}
  end

  defp unlock(a = %Comment{lock: l}), do: %{a | lock: l - 1}

  defp mutex_key(a = %Comment{local_id: l_id, article: %Article{db_id: dbid}}) do
    try do
      @mutext_prefix <> dbid <> ":" <> l_id
    rescue
      ArgumentError -> IO.puts("mutex_key crash: #{inspect(a)}")
    end
  end

  defp to_comment(c_list) when is_list(c_list), do: Enum.map(c_list, &to_comment/1)
  defp to_comment({:ok, comment_map}), do: to_comment(comment_map)
  defp to_comment(%Comment{} = comment), do: comment

  defp to_comment(comment) do
    with {:ok, ar} <- Article.get_from_id(comment[@keys.article_id]),
         {:ok, au} <- Author.get_from_id(comment[@keys.author_id]) do
      %Comment{
        db_id: comment[@keys.db_id],
        article: ar,
        likes: comment[@keys.likes],
        local_id: comment[@keys.local_id],
        author: au,
        parent_id: comment[@keys.parent_id],
        versions: Enum.map(comment[@keys.versions], &CommentVersion.to_version/1),
        updated: Timestamp.from_db_format(comment[@keys.updated])
      }
    end
  end

  defp to_map(c) do
    %{
      @keys.article_id => c.article.db_id,
      @keys.likes => c.likes,
      @keys.local_id => c.local_id,
      @keys.author_id => author_id(c),
      @keys.parent_id => c.parent_id,
      @keys.versions => Enum.map(c.versions, &CommentVersion.to_map/1),
      @keys.updated => Timestamp.to_db_format(c.updated)
    }
    |> add_id(c)
  end

  defp add_id(map, %{db_id: ""}), do: map
  defp add_id(map, %{db_id: id}), do: Map.put(map, "id", id)

  defp author_id(%{author: :anon}), do: :anon
  defp author_id(%{author: %Author{db_id: db_id}}), do: db_id
end
