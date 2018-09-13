defmodule CommentServerTest.Database.Author do
  use ExUnit.Case
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Author

  test "create" do
    d = Domain.create("http://www.test.com/test/author/1")
    username = "test_user"
    c = Author.create(domain: d, local_id: username, username: username)
    assert Author.exists?(username) == false
    Author.insert(c)
    assert Author.exists?(username) == true
    Author.delete(c)
    assert Author.exists?(username) == false
  end

  test "double insert" do
    d = Domain.create("http://www.test.com/author/2")
    username = "test_user2"
    c = Author.create(domain: d, local_id: username, username: username)
    assert Author.exists?(username) == false
    {:ok, a1} = Author.insert(c, true)
    {:ok, a2} = Author.insert(c, true)
    assert a1 == a2
    assert Author.exists?(username) == true
    Author.delete(a1)
    assert Author.exists?(username) == false
  end
end
