defmodule CommentServerTest.Database.Article do
  use ExUnit.Case
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Article

  test "create" do
    a = Article.create("http://www.test.com/test/author/1")
    assert Article.exists?(a) == false
    Article.insert(a)
    assert Article.exists?(a) == true
    Article.delete(a)
    assert Article.exists?(a) == false
  end

  test "double insert" do
    a = Article.create("http://www.test.com/test/author/1")
    assert Article.exists?(a) == false
    {:ok, a1} = Article.insert(a, true)
    {:ok, a2} = Article.insert(a, true)
    assert a1 == a2
    assert Article.exists?(a) == true
    Article.delete(a)
    assert Article.exists?(a) == false
  end
end
