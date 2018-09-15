defmodule CommentServerTest.Database.Article do
  use ExUnit.Case
  alias CommentServer.Content.Domain
  alias CommentServer.Content.Article

  test "create" do
    {:ok, a} = Article.create("http://www.test.com/test/author/2")
    assert Article.exists?(a) == false
    {:ok, a} = Article.insert(a)
    assert Article.exists?(a) == true
    Article.delete(a)
    assert Article.exists?(a) == false
  end

  test "double insert" do
    {:ok, a} = Article.create("http://www.test.com/test/author/1")
    assert Article.exists?(a) == false
    assert Article.fresh?(a) == false
    {:ok, a1} = Article.insert(a)
    assert Article.fresh?(a) == true
    {:ok, a2} = Article.insert(a)
    assert a1.full_url == a2.full_url
    assert a1.db_id != a2.db_id
    assert Article.exists?(a) == true
    Article.delete(a1)
    assert Article.exists?(a) == true
    Article.delete(a2)
    assert Article.exists?(a) == false
  end

  test "insert if stale" do
    {:ok, a} = Article.create("http://www.test.com/test/author/3")
    assert Article.exists?(a) == false
    assert Article.fresh?(a) == false

    {:ok, a1} = Article.insert_if_stale(a)
    assert Article.exists?(a) == true
    assert Article.fresh?(a) == true

    {:ok, a2} = Article.insert_if_stale(a)
    assert a1 == a2
    Article.delete(a)
    assert Article.exists?(a) == false
  end
end
