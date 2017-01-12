require Logger

defmodule Diffusion.SessionSupervisor do
  use Supervisor


  @module __MODULE__
  @sup_name __MODULE__


  def start_link() do
    Supervisor.start_link(@module, [], name:  @sup_name)
  end


  @spec start_child(opts) :: Supervisor.on_start_child when
    opts: [opt],
    opt: {:id, binary}

  def start_child(opts0) do
    session_id = UUID.uuid1()
    opts1 = [{:owner, self()}, {:id, session_id}] ++ opts0
    worker = worker(Diffusion.Session, [opts1], id: session_id)

    Supervisor.start_child(@module, worker)
  end


  def stop_child(_id) do
    # todo:
  end


  def init([]) do
    supervise([], strategy: :one_for_one, restart: :temporary)
  end

end
