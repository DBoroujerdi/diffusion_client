require Logger

defmodule Diffusion.TopicHandlerSup do
  alias Diffusion.TopicHandler

  use Supervisor

  @module __MODULE__
  @sup_name __MODULE__

  def start_link do
    Supervisor.start_link(@module, :ok, name: @sup_name)
  end


  @spec new_handler(String.t, pid, module) :: Supervisor.on_start_child

  def new_handler(topic, owner, callback) do
    args = [topic: topic, owner: owner, callback: callback]
    worker = worker(TopicHandler, [args], [id: topic, restart: :permanent])

    Logger.debug "Adding new handler for topic [#{topic}] with callback: #{callback}"

    Supervisor.start_child(@module, worker)
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
