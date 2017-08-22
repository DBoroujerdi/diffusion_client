require Logger

defmodule Diffusion.Stub.WebsocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, Enum.into(state, %{})}
  end

  def websocket_init(state) do
    send state.owner, self()
    Registry.register(Diffusion.StubRegistry, :stub_msg, :stub_msg)
    {:ok, state}
  end

  def websocket_handle(frame, state) do
    Logger.info "====> #{inspect frame}"
    {:ok, state}
  end

  def websocket_info(info, state) do
    Logger.info "====> #{inspect info}"
    {:ok, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end
end
