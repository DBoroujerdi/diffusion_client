defmodule DiffusionClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :diffusion_client,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger, :gun, :gproc, :crypto],
      mod: {Diffusion.Client, []}
    ]
  end

  defp deps do
    [
      {:gun, git: "https://github.com/ninenines/gun.git"},
      {:gproc, git: "https://github.com/uwiger/gproc.git"},
      {:uuid, "~> 1.1"},
      {:monad, "~> 1.0"},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
      {:ex_spec, "~> 2.0", only: :test}
    ]
  end
end
