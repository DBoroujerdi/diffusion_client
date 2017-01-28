require Logger

defmodule Diffusion.TopicHandlerSup do
  alias Diffusion.Connection

  use Supervisor

  def start_link(%{host: host}) do
    Supervisor.start_link(__MODULE__, :ok, name: via(host))
  end


  @spec add_handler(Connection.t, String.t, pid, module) :: Supervisor.on_start_child

  def add_handler(connection, topic, owner, handler) do
    args = [topic: topic, owner: owner, callback: handler]
    worker = worker(handler, [args], [id: topic, restart: :permanent])

    Logger.debug "Adding new handler for topic [#{topic}] with callback: #{handler}"

    Supervisor.start_child(via(connection.host), worker)
  end


  def via(name) do
    {:via, :gproc, {:n, :l, {__MODULE__, name}}}
  end


  @spec stop_child(Session.t) :: :ok

  def stop_child(_id) do
    # todo:
    :ok
  end

  def init(:ok) do
    Logger.debug "Connection supervisor started."
    supervise([], strategy: :one_for_one, restart: :permanent)
  end

end
