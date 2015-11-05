defmodule LruCache.Mixfile do
  use Mix.Project

  def project do
    [app: :lru_cache,
     version: "0.0.1",
     elixir: "~> 1.2-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :con_cache]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:con_cache, "~> 0.9.0"},
     {:benchfella, "~> 0.2.0"}]
  end
end
