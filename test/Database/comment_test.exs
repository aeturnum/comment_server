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
    {:ok, c1} = Comment.insert_or_update(c)
    assert Comment.exists?(id) == true
    assert Comment.fresh?(id) == true
    {:ok, c2} = Comment.insert_or_update(c)
    assert c1 == c2
    Comment.delete(c1)
    assert Comment.exists?(id) == false
  end

  test "update" do
    {:ok, a} = Article.create("http://www.test.com/comment/1")
    id = "4"
    {:ok, c} = Comment.create(article: a, local_id: id, message: "Hello World")
    {:ok, c2} = Comment.create(article: a, local_id: id, message: "Hello World")
    {:ok, c3} = Comment.create(article: a, local_id: id, message: "New message!")
    {:ok, i_c} = Comment.insert_or_update(c)
    {:ok, i_c2} = Comment.insert_or_update(c2)
    assert i_c == i_c2
    assert length(i_c.versions) == 1
    {:ok, i_c3} = Comment.insert_or_update(c3)
    assert i_c3 != i_c2
    assert i_c3.db_id == i_c2.db_id
    assert length(i_c3.versions) == 2
    Comment.delete(i_c3)
  end
end
