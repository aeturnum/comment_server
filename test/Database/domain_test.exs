defmodule CommentServerTest.Database.Domain do
  use ExUnit.Case
  alias CommentServer.Content.Domain

  test "create" do
    {:ok, d1} = Domain.create("http://www.test.com/test1")
    assert d1.host == "www.test.com"
  end

  test "insert" do
    {:ok, d} = Domain.create("http://www.test2.com/te")
    assert Domain.exists?(d) == false
    assert {:ok, _} = Domain.insert(d)
    assert Domain.exists?(d) == true
    assert :ok == Domain.delete(d)
    assert false == Domain.exists?(d)
  end

  test "double insert" do
    {:ok, d} = Domain.create("http://www.test3.com/te2")
    assert Domain.exists?(d) == false
    assert Domain.fresh?(d) == false
    assert {:ok, v1} = Domain.insert(d)
    assert Domain.fresh?(d) == true
    assert {:ok, v2} = Domain.insert(d)
    assert v1.host == v2.host
    assert v1.db_id != v2.db_id
    assert Domain.exists?(d) == true
    assert :ok == Domain.delete(d)
    assert false == Domain.exists?(d)
  end

  test "exists" do
    {:ok, d1} = Domain.create("http://www.test4.com/test1")
    {:ok, d2} = Domain.create("http://www.test4.com/test2")
    {:ok, d3} = Domain.create("http://www.anothertest.com/test2")
    assert Domain.exists?(d1) == false
    assert Domain.exists?(d2) == false
    assert Domain.exists?(d3) == false
    assert {:ok, _} = Domain.insert(d1)
    assert Domain.exists?(d1) == true
    assert Domain.exists?(d2) == true
    assert Domain.exists?(d3) == false
    assert :ok == Domain.delete(d1)
    assert Domain.exists?(d1) == false
    assert Domain.exists?(d2) == false
    assert Domain.exists?(d3) == false
  end

  test "delete" do
    {:ok, d} = Domain.create("http://www.test5.com/test3")
    assert {:error, _} = Domain.delete(d)
    assert {:ok, _} = Domain.insert(d)
    assert :ok == Domain.delete(d)
    assert {:error, _} = Domain.delete(d)
  end

  test "get non existant" do
    {:ok, d} = Domain.create("http://www.test6.com/test5")
    assert {:ok, nil} == Domain.get_from_host(d.host)
  end
end
