defmodule CommentServer.HTTP.Headers do
  def add_headers(conn, keyword_headers) do
    headers = make_headers(keyword_headers)
    add_headers_to_response(conn, headers)
  end

  def add_headers_to_response(conn, []), do: conn

  def add_headers_to_response(conn, [{key, value} | rest]) do
    Plug.Conn.put_resp_header(conn, key |> to_string, value |> to_string)
    |> add_headers_to_response(rest)
  end

  def make_headers([]), do: []

  def make_headers([key | rest]) do
    add_header([key]) ++ make_headers(rest)
  end

  # def make_headers(request) do
  #   args = [
  #     length: request.size,
  #     mime: request.mime,
  #     disposition: [attachment: request.download, name: request.name]
  #   ]

  #   make_headers(args)
  # end

  defp add_header(location: loc), do: [Location: loc]
  defp add_header(length: length), do: ["content-length": length]
  defp add_header(mime: mime), do: ["content-type": mime]

  defp add_header(disposition: args) do
    attachment = get_attachment(Keyword.get(args, :attachment))
    name = get_name(Keyword.get(args, :name))

    ["content-disposition": "#{attachment}; filename*=UTF-8''#{name}"]
  end

  defp add_header(cookie: cookie_map), do: add_header(cookies: cookie_map)

  # to do set this up properly to deal with many cookies
  defp add_header(cookies: cookie_map) do
    Enum.reduce(
      cookie_map,
      [],
      fn {key, value}, lst ->
        ["set-cookie": Plug.Conn.Cookies.encode(key, %{value: value})] ++ lst
      end
    )
  end

  defp add_header(_), do: []

  defp get_name(name), do: URI.encode(name)

  defp get_attachment(attachment) do
    case attachment do
      true -> "attachment"
      false -> "inline"
      _ -> attachment
    end
  end

  defp get_header([{header, value} | rest], target_header) do
    case header do
      ^target_header -> value
      _ -> get_header(rest, target_header)
    end
  end

  defp get_header([], _target_header), do: nil
end
