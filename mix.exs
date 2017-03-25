defmodule DiffusionClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :diffusion_client,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps() ++ test_deps(),
      preferred_cli_env: [espec: :test]
    ]
  end

  def application do
    [
      applications: [:logger, :gun, :gproc, :crypto],
      mod: {Diffusion.Client, []}
    ]
  end

  defp test_deps do
    [
      {:ex_spec, "~> 2.0", only: :test},
      {:mock, "~> 0.2.0", only: :test},
      {:ranch, git: "https://github.com/ninenines/ranch.git", override: true},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false}
    ]
  end

  defp deps do
    [
      {:gun, git: "https://github.com/ninenines/gun.git", tag: "bc733a2ca5f7d07f997ad6edf184f775b23434aa"},
      {:gproc, git: "https://github.com/uwiger/gproc.git", tag: "01c8fbfdd5e4701e8e4b57b0c8279872f9574b0b"},
      {:uuid, "~> 1.1"},
      {:monad, "~> 1.0"},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
      {:ex_spec, "~> 2.0", only: :test},
      {:mock, "~> 0.2.0", only: :test},
      {:cowboy, git: "https://github.com/ninenines/cowboy.git", only: :test, tag: "a45813c60f0f983a24ea29d491b37f0590fdd087"},
      {:ranch, git: "https://github.com/ninenines/ranch.git", override: true}
    ]
  end
end
