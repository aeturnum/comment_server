defmodule CommentServer.Admin.SystemUser do
  require RethinkDB.Lambda
  import RethinkDB.Lambda
  alias CommentServer.Content.Timestamp
  alias CommentServer.Database.Operations
  alias CommentServer.Util.H
  alias __MODULE__

  @table "system_users"
  @keys %{
    # id from rethinkdb
    db_id: "id",
    username: "username",
    class: "class",
    email: "email",
    password_hash: "password_hash",
    sessions: "sessions",
    updated: "updated"
  }

  @enforce_keys [:username, :class, :email, :password_hash]

  @class_admin "admin"
  @class_user "user"

  defstruct db_id: "",
            username: "",
            email: "",
            class: "",
            sessions: [],
            password_hash: "",
            updated: Timestamp.new()

  defimpl String.Chars, for: SystemUser do
    def to_string(%{db_id: db_id, username: uname, email: em, sessions: s}) do
      "%SystemUser{id: #{db_id}, username: #{uname}, email: #{em}, sessions: #{inspect(s)})"
    end
  end

  def setup_users() do
    with {:ok, user_maps} <- Operations.get(%{}, @table),
         users <- Enum.map(H.as_list(user_maps), &to_system_user/1) do
      Enum.filter(users, fn u ->
        u.class == @class_admin
      end)
      |> case do
        # create admin user

        [] ->
          with username <- "admin",
               password <- UUID.uuid4(:hex),
               # todo: replace with setting
               email <- "dd997@drexel.edu",
               {:ok, user} <-
                 create(username: username, email: email, password: password, class: @class_admin) do
            IO.puts(
              "Creating admin user:\n\tusername: #{username}\n\tpassword: #{password}\n\temail: #{
                email
              }"
            )

            insert_or_update(user)
          end

        _ ->
          :ok
      end

      #
    end
  end

  def create(args) do
    with true <- Keyword.has_key?(args, :username),
         true <- Keyword.has_key?(args, :email),
         true <- Keyword.has_key?(args, :password) do
      %SystemUser{
        username: Keyword.get(args, :username),
        class: Keyword.get(args, :class, @class_user),
        email: Keyword.get(args, :email),
        password_hash: Comeonin.Argon2.hashpwsalt(Keyword.get(args, :password)),
        updated: Timestamp.new()
      }
      |> H.pack(:ok)
    else
      _ -> {:error, nil}
    end
  end

  def load_session(session) do
    case Operations.get(%{}, @table) do
      {:ok, list} ->
        list
        |> H.as_list()
        |> Enum.map(&to_system_user/1)
        |> Enum.filter(fn user ->
          session in user.sessions
        end)
        |> case do
          [] ->
            H.debug("SystemUser.load_session(\"#{session}\") -> nil")
            nil

          [user] ->
            H.debug("SystemUser.load_session(\"#{session}\") -> #{user}")
            user
        end

      error ->
        error
    end
  end

  # catch users that haven't been entered into the db
  def add_session(%SystemUser{db_id: ""}), do: {:error, "User does not exist in DB"}

  def add_session(user = %SystemUser{db_id: _id, sessions: sess}) do
    with new_session <- UUID.uuid4(:hex) do
      IO.puts("Creating new session #{new_session}")

      case update(%{user | sessions: [new_session | sess]}) do
        {:ok, _} -> {:ok, new_session}
        other -> other
      end
    end
  end

  def remove_session(user = %SystemUser{sessions: s}, s_to_remove) do
    %{user | sessions: Enum.filter(s, fn sess -> sess != s_to_remove end)}
    |> update()
    |> case do
      {:ok, user} -> {:ok, user}
      other -> other
    end
  end

  def get_from_username(%SystemUser{username: username}), do: get_map(%{username: username})
  def get_from_username(username), do: get_map(%{username: username})

  def check_user_and_pass(username, password) do
    case get_from_username(username) do
      # no user
      {:ok, nil} ->
        Comeonin.Argon2.dummy_checkpw()
        {:error, "Username and Password do not match"}

      # user
      {:ok, user} ->
        Comeonin.Argon2.check_pass(user, password)
    end
  end

  def exists?(%SystemUser{username: username}),
    do: Operations.exists?(%{username: username}, @table)

  def exists?(username), do: Operations.exists?(%{username: username}, @table)

  def insert_or_update(system_user) do
    case exists?(system_user) do
      true -> update(system_user)
      false -> insert(system_user)
    end
  end

  def delete(%SystemUser{db_id: db_id}), do: Operations.delete(%{id: db_id}, @table)

  defp insert(system_user) do
    to_map(system_user)
    |> Operations.put(@table)
    |> case do
      # todo: add cache
      {:ok, db_id} ->
        result = Map.put(system_user, :db_id, db_id)
        H.debug("SystemUser.Insert: #{inspect(result)}")
        {:ok, result}

      other ->
        other
    end
  end

  defp update(system_user) do
    H.debug("SystemUser.update(#{system_user})")

    system_user
    |> to_map
    |> Operations.update(system_user, @table)

    {:ok, system_user}
  end

  defp get_map(map) do
    case Operations.get(map, @table) do
      {:ok, []} -> {:ok, nil}
      {:ok, result} -> {:ok, to_system_user(result)}
      other -> other
    end
  end

  defp to_system_user(system_user) do
    %SystemUser{
      db_id: system_user[@keys.db_id],
      username: system_user[@keys.username],
      email: system_user[@keys.email],
      class: system_user[@keys.class],
      password_hash: system_user[@keys.password_hash],
      sessions: system_user[@keys.sessions],
      updated: Timestamp.from_db_format(system_user[@keys.updated])
    }
  end

  defp to_map(su) do
    %{
      # We don't include the db_id here because that's managed by the DB.
      @keys.username => su.username,
      @keys.email => su.email,
      @keys.class => su.class,
      @keys.password_hash => su.password_hash,
      @keys.sessions => su.sessions,
      @keys.updated => Timestamp.to_db_format(su.updated)
    }
  end
end
