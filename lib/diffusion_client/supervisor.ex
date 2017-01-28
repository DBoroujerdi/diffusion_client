require Logger

defmodule Diffusion.Supervisor do
  alias Diffusion.ConnectionSup

  use Supervisor


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name:  __MODULE__)
  end


  @spec start_child(map) :: Supervisor.on_start_child

  def start_child(%{host: id} = config) do
    child = supervisor(ConnectionSup, [config], [id: id, restart: :permanent])

    Logger.debug "Adding new connection with id [#{id}] with config: #{inspect config}"

    Supervisor.start_child(__MODULE__, child)
  end


  def stop_child(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end


  def init([]) do
    supervise([], strategy: :one_for_one, restart: :permanent)
  end

end
