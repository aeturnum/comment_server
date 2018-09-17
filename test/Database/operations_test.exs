defmodule CommentServerTest.Database.Operations do
  use ExUnit.Case
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
    Operations.update(%{id: id, hello: "world2", comment_id: 3}, "users")
  end
end
