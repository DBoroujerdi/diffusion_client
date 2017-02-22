defmodule Diffusion.ConnectionTest do
  alias Diffusion.{Connection, Websocket}
  use ExSpec, async: false

  import Mock

  setup_all do
    with_mock Websocket, [
      open: fn(_) -> FakeSocket.start_link() end
    ] do

      {:ok, _} = Connection.start_link(%{host: "host", path: "/path", owner: self()})
      connection_pid = receive do
        {:started, pid} ->
          pid
        error ->
          flunk()
      end

      assert Connection.alive?(connection_pid) == true

      {:ok, connection_pid: connection_pid}
    end
  end

  test "responds to socket ping with ping", %{connection_pid: connection_pid} do
    with_mock Websocket, [
      open: fn(_) -> FakeSocket.start_link() end,
      close: fn(_) -> :ok end
    ] do
      assert Connection.alive?(connection_pid) == true

      Connection.close(connection_pid)
    end
  end

  # test "reconnects on :gun_down" do
  # end

  # test "reconnects when gun socket process dies" do
  # end

  # test "closes gun socket on terminate" do
  # end

  # test "sends data to socket" do
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
