defmodule LruCache do
  @moduledoc ~S"""
  This modules implements a simple LRU cache, using 2 ets tables for it.

  For using it, you need to start it:

      iex> LruCache.start_link(:my_cache, 1000)

  Or add it to your supervisor tree, like: `worker(LruCache, [:my_cache, 1000])`

  ## Using

      iex> LruCache.start_link(:my_cache, 1000)
      {:ok, #PID<0.60.0>}

      iex> LruCache.put(:my_cache, "id", "value")
      :ok

      iex> LruCache.get(:my_cache, "id", touch = false)
      "value"

  To take some action when old keys are evicted from the cache when it is full,
  you can pass an `:evict_fn` option to `LruCache.start_link/3`. This is
  helpful for cleaning up processes that depend on values in the cache, or
  logging, or instrumentation of cache evictions etc.

      iex> evict = fn(key,value) -> IO.inspect("#{key}=#{value} evicted") end
      iex> LruCache.start_link(:my_cache, 10, evict_fn: evict)
      {:ok, #PID<0.60.0>}

  ## Design

  First ets table save the key values pairs, the second save order of inserted elements.
  """
  use GenServer

  defstruct table: nil, ttl_table: nil, size: 0, evict_fn: nil

  @doc """
  Creates an LRU of the given size as part of a supervision tree with a registered name

  ## Options

    * `:evict_fn` - function that accepts (key, value) and takes some action when keys are
      evicted when the cache is full.

  """
  def start_link(name, size, opts \\ []) do
    Agent.start_link(__MODULE__, :init, [name, size, opts], name: name)
  end

  @doc """
  Stores the given `value` under `key` in `cache`. If `cache` already has `key`, the stored
  `value` is replaced by the new one. This updates the order of LRU cache.
  """
  def put(name, key, value, timeout \\ 5000),
    do: Agent.get(name, __MODULE__, :handle_put, [key, value], timeout)

  @doc """
  Updates a `value` in `cache`. If `key` is not present in `cache` then nothing is done.
  `touch` defines, if the order in LRU should be actualized. The function assumes, that
  the element exists in a cache.
  """
  def update(name, key, value, touch \\ true, timeout \\ 5000) do
    if :ets.update_element(name, key, {3, value}) do
      touch && Agent.get(name, __MODULE__, :handle_touch, [key], timeout)
    end

    :ok
  end

  @doc """
  Returns the `value` associated with `key` in `cache`. If `cache` does not contain `key`,
  returns nil. `touch` defines, if the order in LRU should be actualized.
  If `put_fun` is defined and does not return nil, the value returned from `put_fun`
  written to the cache returned. If `put_fun` returns nil, then this function does not
  write to the cache. `touch` defines, if the order in LRU should be actualized.
  """
  def get(name, key, touch \\ true, timeout \\ 5000, put_fun \\ nil) do
    case :ets.lookup(name, key) do
      [{_, _, value}] ->
        touch && Agent.get(name, __MODULE__, :handle_touch, [key], timeout)
        value

      [] ->
        get_with_put(put_fun, name, key, timeout)
    end
  end

  @doc """
  Returns the `value` associated with `key` in `cache`. If `cache` does not contain `key`,
  first we try to run the passed `put_fun`.   """

  @doc """
  Removes the entry stored under the given `key` from cache.
  """
  def delete(name, key, timeout \\ 5000),
    do: Agent.get(name, __MODULE__, :handle_delete, [key], timeout)

  @doc false
  def init(name, size, opts \\ []) do
    ttl_table = :"#{name}_ttl"
    :ets.new(ttl_table, [:named_table, :ordered_set])
    :ets.new(name, [:named_table, :public, {:read_concurrency, true}])
    evict_fn = Keyword.get(opts, :evict_fn)
    %LruCache{ttl_table: ttl_table, table: name, size: size, evict_fn: evict_fn}
  end

  @doc false
  def init({name, size, opts}) do
    init(name, size, opts)
  end

  @doc false
  def handle_put(state = %{table: table}, key, value) do
    delete_ttl(state, key)
    uniq = insert_ttl(state, key)
    :ets.insert(table, {key, uniq, value})
    clean_oversize(state)
    :ok
  end

  @doc false
  def handle_touch(state = %{table: table}, key) do
    delete_ttl(state, key)
    uniq = insert_ttl(state, key)
    :ets.update_element(table, key, [{2, uniq}])
    :ok
  end

  @doc false
  def handle_delete(state = %{table: table}, key) do
    delete_ttl(state, key)
    :ets.delete(table, key)
    :ok
  end

  defp delete_ttl(%{ttl_table: ttl_table, table: table}, key) do
    case :ets.lookup(table, key) do
      [{_, old_uniq, _}] ->
        :ets.delete(ttl_table, old_uniq)

      _ ->
        nil
    end
  end

  defp insert_ttl(%{ttl_table: ttl_table}, key) do
    uniq = :erlang.unique_integer([:monotonic])
    :ets.insert(ttl_table, {uniq, key})
    uniq
  end

  defp clean_oversize(state = %{ttl_table: ttl_table, table: table, size: size}) do
    if :ets.info(table, :size) > size do
      oldest_tstamp = :ets.first(ttl_table)
      [{_, old_key}] = :ets.lookup(ttl_table, oldest_tstamp)
      :ets.delete(ttl_table, oldest_tstamp)
      call_evict_fn(state, old_key)
      :ets.delete(table, old_key)
      true
    else
      nil
    end
  end

  defp call_evict_fn(%{evict_fn: nil}, _old_key), do: nil

  defp call_evict_fn(%{evict_fn: evict_fn, table: table}, key) do
    [{_, _, value}] = :ets.lookup(table, key)
    evict_fn.(key, value)
  end

  defp get_with_put(nil, _name, _key, _timeout), do: nil

  defp get_with_put(put_fun, name, key, timeout) do
    case put_fun.(key) do
      nil ->
        nil

      put_value ->
        put(name, key, put_value, timeout)
        put_value
    end
  end

end
