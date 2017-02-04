defmodule Diffusion.Connection.Test do
  alias Diffusion.{Connection, Websocket}
  use ExSpec, async: true

  import Mock

  setup do
    # with_mock Websocket, [open_websocket: fn(_) -> FakeSocket.start_link() end] do
    #   {:ok, connection} = Connection.start_link(%{host: "host", path: "/path", owner: self()})
    #   receive do
    #     {:connected, _} ->
    #       {:ok, connection: connection}
    #     error ->
    #       flunk()
    #   end
    # end
    :ok
  end

  # test "should establish connection", %{connection: connection} do
  #   assert Connection.alive?(connection) == true
  # end
end


defmodule FakeSocket do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  # # Callbacks

  # def handle_call(msg, _from, [h | t]) do
  #   {:reply, h, t}
  # end

  # def handle_cast({:push, item}, state) do
  #   {:noreply, [item | state]}
  # end
end
