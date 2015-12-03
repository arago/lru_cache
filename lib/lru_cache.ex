defmodule LruCache do
  @moduledoc """
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

  ## Design

  First ets table save the key values pairs, the second save order of inserted elements.
  """
  use GenServer
  @table LruCache

  defstruct table: nil, ttl_table: nil, size: 0

  @doc """
  Creates an LRU of the given size as part of a supervision tree with a registered name
  """
  def start_link(name, size) do
    Agent.start_link(__MODULE__, :init, [name, size], [name: name])
  end

  @doc """
  Stores the given `value` under `key` in `cache`. If `cache` already has `key`, the stored
  `value` is replaced by the new one. This updates the order of LRU cache.
  """
  def put(name, key, value), do: Agent.get(name, __MODULE__, :handle_put, [key, value])

  @doc """
  Updates a `value` in `cache`. If `key` is not present in `cache` then nothing is done.
  `touch` defines, if the order in LRU should be actualized. The function assumes, that
  the element exists in a cache.
  """
  def update(name, key, value, touch \\ true) do
    if :ets.update_element(name, key, {3, value}) do
      touch && Agent.get(name, __MODULE__, :handle_touch, [key])
    end
    :ok
  end

  @doc """
  Returns the `value` associated with `key` in `cache`. If `cache` does not contain `key`,
  returns nil. `touch` defines, if the order in LRU should be actualized.
  """
  def get(name, key, touch \\ true) do
    case :ets.lookup(name, key) do
      [{_, _, value}] ->
        touch && Agent.get(name, __MODULE__, :handle_touch, [key])
        value
      [] ->
        nil
    end
  end

  @doc """
  Removes the entry stored under the given `key` from cache.
  """
  def delete(name, key), do: Agent.get(name, __MODULE__, :handle_delete, [key])

  @doc false
  def init(name, size) do
    ttl_table = :"#{name}_ttl"
    :ets.new(ttl_table, [:named_table, :ordered_set])
    :ets.new(name, [:named_table, :public, {:read_concurrency, true}])
    %LruCache{ttl_table: ttl_table, table: name, size: size}
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

  defp clean_oversize(%{ttl_table: ttl_table, table: table, size: size}) do
    if :ets.info(table, :size) > size do
      oldest_tstamp = :ets.first(ttl_table)
      [{_, old_key}] = :ets.lookup(ttl_table, oldest_tstamp)
      :ets.delete(ttl_table, oldest_tstamp)
      :ets.delete(table, old_key)
      true
    else nil end
  end
end
