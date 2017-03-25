defmodule Diffusion.Stub.Server do
  alias Diffusion.Stub.WebsocketHandler

  use GenServer

  def start() do
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ok = start_cowboy(WebsocketHandler)
    {:ok, %{connected: false}}
  end

  def connection_established do
    GenServer.call(__MODULE__, :is_connected)
  end

  def start_cowboy(mod) do
    dispatch_config = :cowboy_router.compile([
      { :_,
        [
          {"/diffusion_ws", mod, [owner: self()]}
        ]}
    ])

    {:ok, _} = :cowboy.start_clear(:http,
      1,
      [{:port, 8080}],
      %{:env => %{:dispatch => dispatch_config}})

    :ok
  end

  def handle_call(:is_connected, _, state) do
    {:reply, state.connected, state}
  end

  def handle_info(pid, state) when is_pid(pid) do
    {:noreply, Map.merge(state, %{connected: true, handler: pid})}
  end

  def send_message(msg) do
    :gproc.send({:p, :l, :stub_msg}, msg)
  end
end
