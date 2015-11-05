defmodule LruCacheTest do
  use ExUnit.Case
  #doctest LruCache

  test "basic works" do
    assert {:ok, _} = LruCache.start_link(:test1, 10)
    assert :ok = LruCache.put(:test1, 1, "test")
    assert "test" = LruCache.get(:test1, 1)
    assert nil == LruCache.get(:test1, 2)
    assert :ok = LruCache.put(:test1, 1, "test new")
    assert "test new" = LruCache.get(:test1, 1)
    assert :ok = LruCache.delete(:test1, 1)
    assert nil == LruCache.get(:test1, 1)
  end

  test "lru limit works" do
    assert {:ok, _} = LruCache.start_link(:test2, 5)
    Enum.map(1..5, &(LruCache.put(:test2, &1, "test #{&1}")))
    assert "test 1" = LruCache.get(:test2, 1)
    Enum.map(6..10, &(LruCache.put(:test2, &1, "test #{&1}")))
    assert nil == LruCache.get(:test2, 5)
    assert "test 6" = LruCache.get(:test2, 6)
  end
end
