defmodule CommentServer.HTTP.Response do
  alias CommentServer.HTTP.Headers
  alias __MODULE__

  # response object atom
  @r_a :cs_resp

  defstruct status: :ok,
            code: 200,
            json: nil,
            text: ""

  def set_json(conn, json_map) do
    with conn = %{@r_a => r} <- add_struct(conn) do
      Map.put(conn, @r_a, %{r | json: json_map})
    end
  end

  def set_text(conn, text) do
    with conn = %{@r_a => r} <- add_struct(conn) do
      Map.put(conn, @r_a, %{r | text: text})
    end
  end

  def set_redirect(conn, location) do
    conn
    |> set_code(307)
    |> Headers.add_headers(location: location)
    |> set_text(location)
  end

  def set_code(conn, code) do
    with conn = %{@r_a => r} <- add_struct(conn) do
      Map.put(
        conn,
        @r_a,
        Map.put(
          case code >= 400 do
            false -> %{r | status: :ok}
            true -> %{r | status: :error}
          end,
          :code,
          code
        )
      )
    end
  end

  def send_response(conn = %{@r_a => %{json: nil, code: c, text: t}}) do
    Plug.Conn.send_resp(conn, c, t)
  end

  def send_response(conn = %{@r_a => %{json: j, code: c}}) do
    conn
    |> Headers.add_headers(mime: "application/json")
    |> Plug.Conn.send_resp(c, encode_json(j))
  end

  def encode_json(json_object), do: Poison.Encoder.encode(json_object, [])

  defp add_struct(conn = %{@r_a => _}), do: conn
  defp add_struct(conn = %{}), do: Map.put(conn, @r_a, %Response{})
end
