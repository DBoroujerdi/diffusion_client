require Logger

defmodule Diffusion.ConnectionSup do
  alias Diffusion.Connection

  use Supervisor

  @module __MODULE__
  @sup_name __MODULE__


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(@module, :ok, name:  @sup_name)
  end


  @spec start_child(map) :: Supervisor.on_start_child

  def start_child(%{host: id} = config) do
    worker = worker(Connection, [config], [id: id, restart: :permanent])

    Logger.debug "Adding new connection with id [#{id}] with config: #{inspect config}"

    Supervisor.start_child(@module, worker)
  end


  def stop_child(pid) do
    Supervisor.terminate_child(@module, pid)
  end

  def init(:ok) do
    Logger.debug "Connection supervisor started."
    supervise([], strategy: :one_for_one, restart: :permanent)
  end

end
