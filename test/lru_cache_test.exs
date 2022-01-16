defmodule LruCacheTest do
  use ExUnit.Case
  # doctest LruCache

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
    Enum.map(1..5, &LruCache.put(:test2, &1, "test #{&1}"))
    assert "test 1" = LruCache.get(:test2, 1)
    Enum.map(6..10, &LruCache.put(:test2, &1, "test #{&1}"))
    assert nil == LruCache.get(:test2, 5)
    assert "test 6" = LruCache.get(:test2, 6)
  end

  test "ported test `without updater`" do
    LruCache.start_link(:test3, 3)
    LruCache.put(:test3, :a, 1)
    assert(1 == LruCache.get(:test3, :a))
    assert(nil == LruCache.get(:test3, :b))
    LruCache.put(:test3, :a, 2)
    assert(2 == LruCache.get(:test3, :a))
    LruCache.put(:test3, :a, 1)
    assert(:ok == LruCache.delete(:test3, :a))
    assert(:ok == LruCache.delete(:test3, :b))
    assert(nil == LruCache.get(:test3, :a))
    LruCache.put(:test3, :a, 1)
    LruCache.put(:test3, :b, 2)
    LruCache.put(:test3, :c, 3)
    assert(2 == LruCache.get(:test3, :b))
    assert(1 == LruCache.get(:test3, :a))
    assert(3 == LruCache.get(:test3, :c))
    assert(nil == LruCache.get(:test3, :d))
    LruCache.put(:test3, :d, 4)
    assert(nil == LruCache.get(:test3, :b))
    assert(1 == LruCache.get(:test3, :a))
    assert(3 == LruCache.get(:test3, :c))
    assert(4 == LruCache.get(:test3, :d))
  end

  test "ported test `put`" do
    LruCache.start_link(:test4, 3)
    LruCache.put(:test4, :a, 1)
    assert 1 = LruCache.get(:test4, :a)
    assert nil == LruCache.get(:test4, :b)
    LruCache.put(:test4, :a, 2)
    assert 2 = LruCache.get(:test4, :a)
  end

  test "ported test `delete`" do
    LruCache.start_link(:test5, 3)
    LruCache.put(:test5, :a, 1)
    assert :ok = LruCache.delete(:test5, :a)
    assert :ok = LruCache.delete(:test5, :b)
    assert nil == LruCache.get(:test5, :a)
  end

  test "ported test `overflow`" do
    LruCache.start_link(:test6, 3)
    LruCache.put(:test6, :a, 1)
    LruCache.put(:test6, :b, 2)
    LruCache.put(:test6, :c, 3)
    assert 2 = LruCache.get(:test6, :b)
    assert 1 = LruCache.get(:test6, :a)
    assert 3 = LruCache.get(:test6, :c)
    assert nil == LruCache.get(:test6, :d)
    LruCache.put(:test6, :d, 4)
    assert nil == LruCache.get(:test6, :b)
    assert 1 = LruCache.get(:test6, :a)
    assert 3 = LruCache.get(:test6, :c)
    assert 4 = LruCache.get(:test6, :d)
  end

  test "ported test `commit 1d0c419`" do
    LruCache.start_link(:test7, 3)
    LruCache.put(:test7, :a, 1)
    assert 1 = LruCache.get(:test7, :a)
    assert nil == LruCache.get(:test7, :b)
    LruCache.put(:test7, :a, 2)
    assert 2 = LruCache.get(:test7, :a)
    LruCache.put(:test7, :a, 1)
    LruCache.put(:test7, :b, 2)
  end

  test "lru update without touch" do
    assert {:ok, _} = LruCache.start_link(:test8, 5)
    Enum.map(1..5, &LruCache.put(:test8, &1, "test #{&1}"))
    assert "test 1" = LruCache.get(:test8, 1, false)
    assert :ok = LruCache.update(:test8, 1, "test 1+", false)
    LruCache.put(:test8, 6, "test 6")
    assert nil == LruCache.get(:test8, 1, false)
  end

  test "eviction callback" do
    test_pid = self()

    evict_fun = fn k, v ->
      send(test_pid, {:evicted, k, v})
    end

    LruCache.start_link(:test9, 3, evict_fn: evict_fun)

    LruCache.put(:test9, :a, 1)
    LruCache.put(:test9, :b, 2)
    LruCache.put(:test9, :c, 3)
    LruCache.put(:test9, :d, 4)
    LruCache.put(:test9, :e, 5)

    assert_received {:evicted, :a, 1}
    assert_received {:evicted, :b, 2}
    refute_received {:evicted, :c, 3}
  end

  test "yield" do
    assert {:ok, _} = LruCache.start_link(:test10, 5)
    assert nil == LruCache.get(:test10, :a)

    # Inserts value returned by function if not found.
    LruCache.yield(:test10, :a, fn _key -> 1 end)
    assert 1 == LruCache.get(:test10, :a)

    # Does not insert on nil return.
    LruCache.yield(:test10, :b, fn _key -> nil end)
    assert nil == LruCache.get(:test10, :b)

    # Does not modify value if found.
    LruCache.put(:test10, :c, 1)
    assert 1 == LruCache.yield(:test10, :c, fn key -> key + 1 end)
  end

end
