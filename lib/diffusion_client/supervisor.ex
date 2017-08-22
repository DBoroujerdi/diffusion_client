require Logger

defmodule Diffusion.Connections.Supervisor do
  alias Diffusion.ConnectionSup

  use Supervisor

  @moduledoc """
  Top level supervisor that supervises each connection supervisor.
  """


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name:  __MODULE__)
  end


  @spec start_socket_connection(map) :: Supervisor.on_start_child

  def start_socket_connection(%{host: id} = config) do
    child = supervisor(ConnectionSup, [config], [id: id, restart: :permanent])

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
