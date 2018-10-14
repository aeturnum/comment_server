defmodule CommentServer.Admin.Schedule do
  alias CommentServer.Content.Timestamp
  alias CommentServer.Database.Operations
  alias CommentServer.Admin.SystemUser
  alias CommentServer.Content.Article
  alias CommentServer.Util.H
  alias __MODULE__

  @table "schedule"
  @keys %{
    # id from rethinkdb
    db_id: "id",
    article: "article",
    article_id: "article_id",
    min_interval: "min_interval",
    continuous: "continuous",
    created_by: "created_by",
    created_by_id: "created_by_id",
    updated: "updated"
  }

  @enforce_keys [:article, :created_by]

  defstruct db_id: "",
            article: nil,
            min_interval: "",
            last_task: nil,
            continuous: false,
            created_by: nil,
            updated: Timestamp.new()

  def create(args) do
    optional_keys = [:min_iterval, :continuous]
    defaults = [min_iterval: ~T[12:00:00], continuous: false]

    with true <- Keyword.has_key?(args, :article),
         true <- Keyword.has_key?(args, :created_by) do
      Enum.reduce(
        optional_keys,
        %Schedule{
          article: Keyword.get(args, :article),
          created_by: Keyword.get(args, :created_by),
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

  defp to_schedule(schedule) do
    with {:ok, article} <- Article.get_from_id(schedule[@keys.article_id]),
         {:ok, user} <- SystemUser.get_from_id(schedule[@keys.created_by_id]) do
      %Schedule{
        db_id: schedule[@keys.db_id],
        article: article,
        created_by: user,
        min_interval: Time.from_iso8601!(schedule[@keys.min_interval]),
        continuous: schedule[@keys.continuous],
        updated: Timestamp.from_db_format(schedule[@keys.updated])
      }
    end
  end

  defp to_map(s) do
    %{
      # We don't include the db_id here because that's managed by the DB.
      @keys.article_id => s.article.db_id,
      @keys.created_by_id => s.created_by.db_id,
      @keys.min_interval => Time.to_iso8601(s.min_interval),
      @keys.continuous => s.continuous,
      @keys.updated => Timestamp.to_db_format(s.updated)
    }
  end
end
