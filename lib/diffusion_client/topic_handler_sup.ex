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
