defmodule CommentServerTest.Database.Operations do
  use ExUnit.Case
  require RethinkDB.Lambda
  import RethinkDB.Lambda
  alias CommentServer.Database.Operations

  # setup_all do
  #   Operations.setup_tables()
  #   on_exit(:teardown, fn -> Operations.drop_tables() end)
  #   :ok
  # end

  test "insert" do
    {:ok, id} = Operations.put(%{hello: "world", comment_id: 1}, "users")
    assert Operations.exists?(id, "users")
    {:ok, id2} = Operations.put(%{hello: "world", comment_id: 2}, "users")
    assert Operations.exists?(id2, "users")

    {:ok, doc1} = Operations.get(%{comment_id: 1}, "users")
    assert doc1["hello"] == "world"
    assert doc1["comment_id"] == 1

    {:ok, cnt} = Operations.count(%{hello: "world"}, "users")
    assert cnt == 2
  end

  test "update" do
    {:ok, id} = Operations.put(%{hello: "world", comment_id: 3}, "users")
    Operations.update(%{id: id, hello: "world2", comment_id: 3}, %{db_id: id}, "users")
  end

  test "search" do
    {:ok, id} = Operations.put(%{hello: "bob", c_id: 10}, "users")
    assert Operations.exists?(id, "users")
    {:ok, id2} = Operations.put(%{hello: "john", c_id: 20}, "users")
    assert Operations.exists?(id2, "users")

    {:ok, id3} = Operations.put(%{hello: "sam", c_id: 5, list: ["a", "b", "c"]}, "users")
    assert Operations.exists?(id, "users")

    {:ok, user} = Operations.search(lambda(fn u -> u["hello"] == "bob" end), "users")
    assert user["id"] == id

    {:ok, list} = Operations.search(lambda(fn u -> u["c_id"] > 9 end), "users")
    assert length(list) == 2

    # todo: figure out how to use search on sub-containers
    # {:ok, list_user} = Operations.search(lambda(fn u -> u[:list] == 3 end), "users")
    # IO.inspect(list_user)
  end
end
