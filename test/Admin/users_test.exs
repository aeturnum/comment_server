defmodule CommentServerTest.Admin.SystemUser do
  use ExUnit.Case
  alias CommentServer.Admin.SystemUser
  alias CommentServer.Database.Operations

  test "create" do
    {:ok, u} =
      SystemUser.create(
        username: "test",
        email: "test@gmail.com",
        password: "test"
      )

    {:ok, u} = SystemUser.insert_or_update(u)

    SystemUser.check_user_and_pass("test", "test2")
    SystemUser.check_user_and_pass("test", "test")

    :ok == SystemUser.delete(u)
  end

  test "session" do
    {:ok, u} =
      SystemUser.create(
        username: "test2",
        email: "test@gmail.com",
        password: "test"
      )

    {:ok, u} = SystemUser.insert_or_update(u)

    {:ok, sess} = SystemUser.add_session(u)

    {:ok, u2} = SystemUser.get_from_username(u.username)
    List.first(u2.sessions) == sess
  end
end
