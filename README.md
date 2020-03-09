# LruCache

Simple LRU Cache, implemented with `ets`.

## Installation

The package can be installed as:

  1. Add lru_cache to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:lru_cache, "~> 0.1.0"}]
  end
```

  2. Ensure lru_cache is started before your application:

```elixir
  def application do
    [applications: [:lru_cache]]
  end
```

## Using

Typically you want to start the cache from a supervisor:

```elixir
worker(LruCache, [:my_cache, 10])
```

Or starting it manually:

```elixir
LruCache.start_link(:my_cache, 10)
```

The resulting process and ets table will be registered under this alias. Now you can use the cache as follows:

```elixir
LruCache.put(:my_cache, "id", "value")
LruCache.get(:my_cache, "id")
LruCache.get(:my_cache, "id", touch = false)
LruCache.update(:my_cache, "id", "new_value", touch = false)
LruCache.delete(:my_cache, "id")
```
