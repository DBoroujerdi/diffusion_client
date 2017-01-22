
defmodule Diffusion.Supervisor do
  use Supervisor

  alias Diffusion.Session


  @module __MODULE__
  @sup_name __MODULE__


  @spec start_link() :: Supervisor.on_start

  def start_link() do
    Supervisor.start_link(@module, [], name:  @sup_name)
  end


  @spec start_child(opts) :: Supervisor.on_start_child when
    opts: [opt],
    opt: {:id, binary}

  def start_child(opts) do
    session_id = UUID.uuid1()
    opts = [{:owner, self()}, {:id, session_id}] ++ opts
    worker = worker(Session, [opts], [id: session_id, restart: :temporary])

    Supervisor.start_child(@module, worker)
  end


  @spec stop_child(Session.t) :: :ok

  def stop_child(_id) do
    # todo:
    :ok
  end


  def init([]) do
    supervise([], strategy: :one_for_one, restart: :temporary)
  end

end
