defmodule CommentServerTest.Database.Comment do
  use ExUnit.Case
  alias CommentServer.Content.Article
  alias CommentServer.Content.Comment

  test "create" do
    {:ok, a} = Article.create("http://www.test.com/comment/1")
    id = "1"
    {:ok, c} = Comment.create(article: a, local_id: id, message: "Hello World")
    assert Comment.exists?(id) == false
    {:ok, c} = Comment.insert(c)
    assert Comment.exists?(id) == true
    Comment.delete(c)
    assert Comment.exists?(id) == false
  end

  test "double insert" do
    {:ok, a} = Article.create("http://www.test.com/comment/1")
    id = "2"
    {:ok, c} = Comment.create(article: a, local_id: id, message: "Hello World")
    assert Comment.exists?(id) == false
    assert Comment.fresh?(id) == false
    {:ok, c1} = Comment.insert(c)
    assert Comment.exists?(id) == true
    assert Comment.fresh?(id) == true
    {:ok, c2} = Comment.insert(c)
    assert c1.local_id == c2.local_id
    assert c1.db_id != c2.db_id
    assert Comment.exists?(id) == true
    Comment.delete(c1)
    assert Comment.exists?(id) == true
    Comment.delete(c2)
    assert Comment.exists?(id) == false
  end

  test "insert if stale" do
    {:ok, a} = Article.create("http://www.test.com/comment/1")
    id = "3"
    {:ok, c} = Comment.create(article: a, local_id: id, message: "Hello World")
    assert Comment.exists?(id) == false
    assert Comment.fresh?(id) == false
    {:ok, c1} = Comment.insert_if_stale(c)
    assert Comment.exists?(id) == true
    assert Comment.fresh?(id) == true
    {:ok, c2} = Comment.insert_if_stale(c)
    assert c1 == c2
    Comment.delete(c1)
    assert Comment.exists?(id) == false
  end
end
