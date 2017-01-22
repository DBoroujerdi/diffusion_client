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


  @spec new_connection(String.t, opts) :: Supervisor.on_start_child when opts: [{atom, any}]

  def new_connection(id, opts) do
    worker = worker(Connection, [opts], [id: id, restart: :temporary])

    Logger.debug "Adding new connection with id [#{id}] with opts: #{opts}"

    Supervisor.start_child(@module, worker)
  end


  @spec stop_child(Session.t) :: :ok

  def stop_child(_id) do
    # todo:
    :ok
  end

  def init(:ok) do
    Logger.debug "Connection supervisor started."
    supervise([], strategy: :one_for_one, restart: :temporary)
  end

end
