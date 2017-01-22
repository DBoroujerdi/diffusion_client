
defmodule Diffusion.Supervisor do
  alias Diffusion.{Router, ConnectionSup, TopicHandlerSup}

  use Supervisor


  @module __MODULE__
  @sup_name __MODULE__


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(@module, [], name:  @sup_name)
  end


  def init([]) do
    children = [
      worker(Router, []),
      supervisor(ConnectionSup, []),
      supervisor(TopicHandlerSup, [])
    ]

    supervise(children, strategy: :one_for_one, restart: :permanent)
  end

end
