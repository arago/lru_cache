defmodule LruCache.Mixfile do
  use Mix.Project
  @github "https://github.com/arago/lru_cache"

  def project do
    [
      app: :lru_cache,
      version: "0.1.3",
      elixir: "~> 1.2-dev",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "LRU Cache",
      source_url: @github,
      description: description(),
      package: package()
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :dev}, {:ex_doc, "~> 0.11", only: :dev}]
  end

  defp description do
    "ETS-based LRU Cache"
  end

  defp package do
    [
      maintainers: ["Dmitry Russ(Aleksandrov)"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => @github}
    ]
  end
end
