defmodule CommentServer.HTTP.Routes do
  alias CommentServer.Util.H
  alias CommentServer.HTTP.Headers
  alias CommentServer.HTTP.Response
  alias CommentServer.Admin.SystemUser

  def login(conn = %{params: params}) do
    case Map.has_key?(params, :username) && Map.has_key?(params, :password) do
      true ->
        case SystemUser.check_user_and_pass(params.username, params.password) do
          {:ok, user} ->
            case SystemUser.add_session(user) do
              {:ok, session} ->
                conn
                |> Headers.add_headers(cookie: %{session: session})
                |> Response.set_redirect("/")

              {:error, why} ->
                conn
                |> Response.set_text("Could not add session: #{inspect(why)}")
                |> Response.set_code(500)
            end

          {:error, _} ->
            conn
            |> Response.set_text("Username and Password do not match a known user")
            |> Response.set_code(401)
        end

      false ->
        conn
        |> Response.set_text("Must specify a username and password")
        |> Response.set_code(400)
    end
    |> Response.send_response()
  end
end
