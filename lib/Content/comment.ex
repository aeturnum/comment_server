defmodule CommentServer.Content.Comment do
  alias CommentServer.Database.Operations
  alias CommentServer.Content.Article
  alias CommentServer.Content.Author
  alias CommentServer.Util.H
  alias CommentServer.Cache
  alias __MODULE__

  @table "comments"
  @cache_name :cache_comments
  @keys %{
    # id from rethinkdb
    db_id: "id",
    article: "article",
    article_id: "article_id",
    author: "author",
    author_id: "author_id",
    parent_id: "parent_id",
    local_id: "local_id",
    message: "message",
    likes: "likes",
    deleted: "deleted"
  }
  # from python code
  # row = [comment['id'], user.id, req_info.thread, comment['parent'], comment['thread']]
  # row.extend([comment['createdAt'], comment['raw_message'], comment['likes']])
  @enforce_keys [:article, :local_id, :message]

  defstruct db_id: "",
            article: nil,
            local_id: nil,
            author: :anon,
            parent_id: nil,
            message: nil,
            likes: 0,
            deleted: false

  def create(args) do
    # check our arguments
    optional_keys = [:author, :parent_id, :likes, :deleted]
    defaults = [author: :anon, parent_id: nil, likes: 0, deleted: false]

    with true <- Keyword.has_key?(args, :article),
         true <- Keyword.has_key?(args, :local_id),
         true <- Keyword.has_key?(args, :message) do
      Enum.reduce(
        optional_keys,
        %Comment{
          article: Keyword.get(args, :article),
          local_id: Keyword.get(args, :local_id),
          message: Keyword.get(args, :message)
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

  def exists?(%Comment{} = c), do: Operations.exists?(%{local_id: c.local_id}, @table)
  def exists?(l_id), do: Operations.exists?(%{local_id: l_id}, @table)
  def get_from_local_id(l_id), do: Operations.get(%{local_id: l_id}, @table) |> to_comment
  # todo: insert domain if needed
  def insert(comment, need_db_id \\ false) do
    case exists?(comment) do
      # todo: is this right?
      true ->
        case need_db_id do
          true ->
            # TODO: Use cache to avoid this
            # need this now to include db_id
            result = get_from_local_id(comment.local_id)
            H.debug("Avoided inserting duplicate comment: #{inspect(comment)}", result)
            {:ok, result}

          false ->
            {:ok, comment}
        end

      false ->
        with {:ok, article} <- Article.insert(comment.article, true),
             {:ok, author} <- Author.insert(comment.author, true),
             comment <- Map.put(comment, :article, article),
             comment <- Map.put(comment, :author, author) do
          comment
          |> to_map
          |> Operations.put(@table)
          |> case do
            # todo: add cache
            {:ok, db_id} ->
              {:ok, Map.put(comment, :db_id, db_id)}

            other ->
              other
          end
        else
          other -> other
        end
    end
  end

  def delete(%Comment{local_id: local_id}), do: Operations.delete(%{local_id: local_id}, @table)
  def delete(%Comment{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  defp primary_key(%Comment{} = comment), do: comment.local_id
  defp primary_key(comment), do: Map.fetch!(comment, @keys.local_id)

  defp to_comment(c_list) when is_list(c_list), do: Enum.map(c_list, &to_comment/1)
  defp to_comment({:ok, comment_map}), do: to_comment(comment_map)
  defp to_comment(%Comment{} = comment), do: comment

  defp to_comment(comment) do
    %Comment{
      db_id: comment[@keys.db_id],
      article: Article.get_from_id(comment[@keys.article_id]),
      local_id: comment[@keys.local_id],
      author: Author.get_from_id(comment[@keys.author_id]),
      parent_id: comment[@keys.parent_id],
      message: comment[@keys.message],
      likes: comment[@keys.likes],
      deleted: comment[@keys.deleted]
    }
  end

  defp to_map(c) do
    %{
      @keys.article_id => c.article.db_id,
      @keys.local_id => c.local_id,
      @keys.author_id => author_id(c),
      @keys.parent_id => c.parent_id,
      @keys.message => c.message,
      @keys.likes => c.likes,
      @keys.deleted => c.deleted
    }
  end

  defp author_id(%{author: :anon}), do: :anon
  defp author_id(%{author: %Author{db_id: db_id}}), do: db_id
end
