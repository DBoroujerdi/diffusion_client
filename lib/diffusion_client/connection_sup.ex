require Logger

defmodule Diffusion.ConnectionSup do
  alias Diffusion.{Connection, TopicHandlerSup}

  use Supervisor


  @spec start_link(map) :: Supervisor.on_start

  def start_link(%{host: host} = config) do
    Supervisor.start_link(__MODULE__, config, name: via(host))
  end


  def via(name) do
    {:via, :gproc, {:n, :l, {__MODULE__, name}}}
  end


  def init(config) do
    Logger.debug "Connection supervisor started."

    children = [
      worker(Connection, [config]),
      supervisor(TopicHandlerSup, [config])
    ]

    supervise(children, strategy: :one_for_one, restart: :permanent)
  end

end
