defmodule CommentServerTest.Database.Author do
  use ExUnit.Case
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Author

  test "create" do
    {:ok, d} = Domain.create("http://www.test.com/test/author/1")
    username = "test_user"
    {:ok, c} = Author.create(domain: d, username: username)
    assert Author.exists?(username) == false
    {:ok, a} = Author.insert(c)
    assert Author.exists?(username) == true
    Author.delete(a)
    assert Author.exists?(username) == false
  end

  test "double insert" do
    {:ok, d} = Domain.create("http://www.test.com/author/2")
    username = "test_user2"
    {:ok, c} = Author.create(domain: d, username: username)
    assert Author.exists?(username) == false
    assert Author.fresh?(username) == false
    {:ok, a1} = Author.insert(c)
    assert Author.exists?(username) == true
    assert Author.fresh?(username) == true
    {:ok, a2} = Author.insert(c)
    assert a1.username == a2.username
    assert a1.db_id != a2.db_id
    assert Author.exists?(username) == true
    Author.delete(a1)
    assert Author.exists?(username) == true
    Author.delete(a2)
    assert Author.exists?(username) == false
    assert Author.fresh?(username) == false
  end

  test "insert if stale" do
    {:ok, d} = Domain.create("http://www.test.com/author/2")
    username = "test_user3"
    {:ok, a} = Author.create(domain: d, username: username)
    assert Author.exists?(username) == false
    assert Author.fresh?(username) == false
    {:ok, a1} = Author.insert_if_stale(a)
    assert Author.exists?(username) == true
    assert Author.fresh?(username) == true
    {:ok, a2} = Author.insert_if_stale(a)
    assert a1 == a2
    Author.delete(a1)
    assert Author.exists?(username) == false
    assert Author.fresh?(username) == false
  end
end
