require Logger

defmodule Diffusion.TopicHandlerSup do
  alias Diffusion.Connection

  use Supervisor

  def start_link(%{host: host}) do
    Supervisor.start_link(__MODULE__, :ok, name: via(host))
  end

  def via(name) do
    {:via, :gproc, {:n, :l, {__MODULE__, name}}}
  end


  @spec start_child(Connection.t, Supervisor.Spec.spec) :: Supervisor.on_start_child

  def start_child(connection, child_spec) do
    Supervisor.start_child(via(connection.host), child_spec)
  end

  @spec stop_child(Connection.t, pid) :: :ok

  def stop_child(connection, child) do
    Supervisor.terminate_child(via(connection.host), child)
  end

  def init(:ok) do
    Logger.debug "Connection supervisor started."
    supervise([], strategy: :one_for_one, restart: :permanent)
  end

end
