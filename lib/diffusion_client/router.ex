require Logger

defmodule Diffusion.Router do
  alias Diffusion.{Connection, TopicHandler}
  alias Diffusion.Websocket.Protocol
  alias Protocol.{DataMessage, ConnectionResponse}

  @moduledoc """
  Decodes and routes diffusion messages recieved from the connection
  to the appropriate topic handler.
  """

  use GenServer

  @server __MODULE__


  # Client API
  def start_link do
    GenServer.start_link(@server, :ok, name: @server)
  end

  def route(bin) when is_binary(bin) do
    GenServer.cast(@server, {:message, self(), bin})
  end

  def subscribe(key) do
    Logger.debug "#{inspect self()}: subscribing for events #{inspect key}"
    :gproc.reg({:p, :l, {:topic_event, key}})
  end

  # Server callbacks
  def init(:ok) do
    {:ok, :ok}
  end

  def handle_cast({:message, connection, message}, _) do
    try do
      Protocol.decode(message) |> maybe_route(connection)
    rescue
      e in RuntimeError ->
        Logger.error("An error occurred: " <> e.message)
    end
    {:noreply, :ok}
  end

  defp maybe_route(message, connection) do
    case message do
      %DataMessage{type: 25} ->
        Connection.send(connection, Protocol.encode(message))
      %DataMessage{type: 20, headers: [topic_headers]} = msg ->
        Logger.debug "Topic load msg #{inspect msg}"

        # todo: this needs to be more elegant
        case :binary.split(topic_headers, "!") do
          [topic, topic_alias] ->
            TopicHandler.handle(topic, {:topic_loaded, "!" <> topic_alias})
          _ ->
            Logger.error "error parsing headers [#{inspect topic_headers}]"
        end
      %DataMessage{type: 21, headers: [topic_alias|_tail]} = msg ->
        TopicHandler.handle(topic_alias, {:topic_delta, msg})
      %DataMessage{} = msg ->
        Logger.debug "data msg #{inspect msg}"
      %ConnectionResponse{} ->
        Logger.debug "connection response"
      msg ->
        Logger.error "unexpected msg #{inspect msg}"
    end
  end
end
