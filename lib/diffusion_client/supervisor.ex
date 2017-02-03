require Logger

defmodule Diffusion.Supervisor do
  alias Diffusion.ConsumerSup

  use Supervisor


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name:  __MODULE__)
  end


  @spec start_socket_consumer(map) :: Supervisor.on_start_child

  def start_socket_consumer(%{host: id} = config) do
    child = supervisor(ConsumerSup, [config], [id: id, restart: :permanent])

    Logger.debug "Adding new connection with id [#{id}] with config: #{inspect config}"

    Supervisor.start_child(__MODULE__, child)
  end


  def stop_child(connection) do
    if Supervisor.terminate_child(__MODULE__, connection.host) == :ok do
      Supervisor.delete_child(__MODULE__, connection.host)
    else
      {:error, :no_child}
    end
  end


  def init([]) do
    supervise([], strategy: :one_for_one, restart: :permanent)
  end

end
