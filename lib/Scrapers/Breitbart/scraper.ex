defmodule CommentServer.Scrapers.Breitbart do
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Article
  alias CommentServer.Content.Author
  alias CommentServer.Content.Comment
  alias CommentServer.Util.H
  alias __MODULE__

  @api_key "E8Uh5l5fHZ6gD8U3KycjAIAk46f68Zw7C6eW8WSjZvCLXebZ7p0r1yrYDrLilk2F"
  @disqus_regex ~r/var\s*disqus_identifier\s*=\s*'(\d+)'/

  def scrape(url) do
    create_initial_data_structure(url)
    |> get_disqus_id()
    |> get_article_title()
    |> get_first_comments()
    |> page_comments()
    |> IO.inspect()
  end

  defp create_initial_data_structure(url) do
    with {:ok, article} <- Article.create(url),
         {:ok, article} <- Article.insert(article) do
      %{article: article, error: nil}
    else
      other -> %{error: other}
    end
  end

  defp get_disqus_id(s = %{error: nil, article: article}) do
    with {:get, {:ok, %{body: body}}} <-
           {:get, HTTPoison.get(article.full_url, [], follow_redirect: true)},
         s <- Map.put(s, :article_body, body),
         {:regex, [_full_match, dqid]} <- {:regex, Regex.run(@disqus_regex, body)},
         s <- Map.put(s, :disqus_id, dqid) do
      s
    else
      {:get, e} ->
        err("Getting article Content failed: #{inspect(e)}", s)

      # assume the put is successful 😅
      {:regex, _e} ->
        err("Could not find disquis id in #{s.article_body}", s)
    end
  end

  defp get_article_title(s = %{article_body: body}) do
    Map.put(
      s,
      :title,
      Enum.reduce_while(Floki.find(body, "meta"), "Unknown Title", fn {"meta", items, opts},
                                                                      default ->
        case items do
          [{"property", "og:title"}, {"content", title}] -> {:halt, title}
          other -> {:cont, default}
        end
      end)
    )
  end

  defp get_first_comments(s = %{disqus_id: disqus_id}) do
    "https://disqus.com/embed/comments/"
    |> HTTPoison.get(
      [],
      params: [{"base", "default"}, {"f", "breitbartproduction"}, {"t_i", disqus_id}]
    )
    |> case do
      {:ok, %{body: body}} ->
        case Floki.find(body, "#disqus-threadData") do
          [{"script", [{"type", "text/json"}, {"id", "disqus-threadData"}], [json]}] ->
            # actually we just want the thread id
            Map.put(s, :thread_id, Poison.decode!(json)["response"]["thread"]["id"])

          other ->
            err("Could not find comments in response: #{body}", s)
        end

      other ->
        err("Could not get comments info from disqus: #{inspect(other)}", s)
    end
  end

  defp comments_params(thread_id, nil) do
    [
      # god if only we could ask for more
      {"limit", 100},
      {"forum", "breitbartproduction"},
      {"api_key", @api_key},
      {"thread", thread_id},
      {"order", "popular"}
    ]
  end

  defp comments_params(thread_id, %{"cursor" => %{"next" => next}}) do
    [{"cursor", next} | comments_params(thread_id, nil)]
  end

  defp page_comments(s = %{thread_id: thread_id}, comments \\ nil) do
    params = comments_params(thread_id, comments)

    with {:get, {:ok, %{body: body}}} <-
           {:get,
            HTTPoison.get(
              "https://disqus.com/api/3.0/threads/listPostsThreaded",
              [],
              params: params
            )},
         {:decode, {:ok, comment_page}} <- {:decode, Poison.decode(body)},
         {:task, {:ok, _}} <- {:task, Task.start(fn -> process_comments(s, comment_page) end)} do
      case comment_page do
        # more to go
        %{"cursor" => %{"hasNext" => true}} ->
          page_comments(s, comment_page)

        # final
        other ->
          s
      end
    else
      {:get, other} ->
        err("Failed to get comments at with params #{inspect(params)}: #{inspect(other)}", s)

      {:decode, other} ->
        err("Failed to decode response to JSON #{inspect(params)}: #{inspect(other)}", s)

      {:task, other} ->
        err("Failed to start task #{inspect(params)}: #{inspect(other)}", s)
    end
  end

  defp process_comments(s = %{article: a}, comments) do
    comments["response"]
    |> Enum.each(fn comment ->
      Task.start(fn ->
        load_and_save_author(comment, a.domain)
        |> save_comment()
      end)
    end)
  end

  defp get_author(author, domain) do
    with name <- Map.get(author, "name") do
      {:ok, a_object} =
        Author.create(
          domain: domain,
          username: Map.get(author, "username", name),
          name: name,
          profile_url: author["profileUrl"],
          location: author["location"],
          joined_at: author["joinedAt"]
        )

      a_object
    end
  end

  defp load_and_save_author(comment = %{"author" => author}, domain) do
    # todo: handle anon
    # "free"
    author = author |> Map.delete("avatar")
    a_object = get_author(author, domain)

    case Author.lock_for_update(a_object) do
      {a_object, true} ->
        # we are now locked!

        with {:ok, %{body: body}} <-
               HTTPoison.get(
                 "https://disqus.com/api/3.0/users/details.json",
                 [],
                 params: [
                   {"user", author["id"]},
                   {"api_key", @api_key}
                 ]
               ),
             #
             {:ok, detail_json} <- Poison.decode(body) do
          a_object
          |> Map.put(:total_posts, detail_json["numPosts"])
          |> Map.put(:total_likes, detail_json["numLikesReceived"])
          # will unlock
          |> Author.insert_or_update()
          |> case do
            {:ok, inserted_author} ->
              Map.put(comment, "author", inserted_author)
          end
        end

      {a_object, false} ->
        with {:ok, inserted_author} <- Author.get_from_username(a_object) do
          Map.put(comment, "author", inserted_author)
        end
    end
  end

  defp save_comment(comment) do
    IO.puts("comment: #{comment["id"]}, author: #{comment["author"]}")
    :ok
  end

  defp err(error_string, s), do: Map.put(s, :error, error_string)

  # error states
  defp get_disquis_id(state = %{error: err}), do: state
end
