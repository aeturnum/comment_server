defmodule CommentServerTest.Database.Comment do
  use ExUnit.Case
  alias CommentServer.Content.Article
  alias CommentServer.Content.Comment

  test "create" do
    a = Article.create("http://www.test.com/comment/1")
    id = "1"
    c = Comment.create(article: a, local_id: id, message: "Hello World")
    assert Comment.exists?(id) == false
    Comment.insert(c)
    assert Comment.exists?(id) == true
    Comment.delete(c)
    assert Comment.exists?(id) == false
  end

  test "double insert" do
    a = Article.create("http://www.test.com/comment/1")
    id = "1"
    c = Comment.create(article: a, local_id: id, message: "Hello World")
    assert Comment.exists?(id) == false
    {:ok, c1} = Comment.insert(c, true)
    {:ok, c2} = Comment.insert(c, true)
    assert c1 == c2
    assert Comment.exists?(id) == true
    Comment.delete(c1)
    assert Comment.exists?(id) == false
  end
end
