defmodule CommentServer.Content.CommentVersion do
  alias CommentServer.Content.Timestamp
  alias CommentServer.Util.H
  alias __MODULE__

  @keys %{
    message: "message",
    likes: "likes",
    deleted: "deleted",
    updated: "updated"
  }
  # from python code
  # row = [comment['id'], user.id, req_info.thread, comment['parent'], comment['thread']]
  # row.extend([comment['createdAt'], comment['raw_message'], comment['likes']])
  @enforce_keys [:message]

  defstruct message: nil,
            likes: 0,
            deleted: false,
            updated: Timestamp.now()

  defimpl String.Chars, for: CommentVersion do
    def to_string(%{message: m}) do
      "%CV{message: #{m})"
    end
  end

  def create(args) do
    # check our arguments
    optional_keys = [:likes, :deleted]
    defaults = [likes: 0, deleted: false]

    with true <- Keyword.has_key?(args, :message) do
      Enum.reduce(
        optional_keys,
        %CommentVersion{
          message: Keyword.get(args, :message),
          updated: Timestamp.now()
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

  def add_if_changed(new_version, versions = [last_version | _]) do
    H.debug("add_if_changed(#{inspect(new_version)}, #{inspect(versions)})")

    case has_changed(new_version, last_version) do
      true ->
        {true, [new_version | versions], new_version.updated}

      false ->
        {false, versions, last_version.updated}
    end
  end

  defp has_changed(
         %CommentVersion{message: n_m, likes: n_l, deleted: n_d},
         %CommentVersion{message: o_m, likes: o_l, deleted: o_d}
       ),
       do: n_m != o_m || n_l != o_l || n_d != o_d

  def to_version({:ok, version_map}), do: to_version(version_map)
  def to_version(%CommentVersion{} = comment), do: comment

  def to_version(comment) do
    %CommentVersion{
      message: comment[@keys.message],
      likes: comment[@keys.likes],
      deleted: comment[@keys.deleted],
      updated: Timestamp.from_db_format(comment[@keys.updated])
    }
  end

  def to_map(c) do
    %{
      @keys.message => c.message,
      @keys.likes => c.likes,
      @keys.deleted => c.deleted,
      @keys.updated => Timestamp.to_db_format(c.updated)
    }
  end
end
