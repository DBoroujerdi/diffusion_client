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

  # Server callbacks
  def init(:ok) do
    {:ok, %{:alias_map => %{}}}
  end

  def handle_cast({:message, connection, message}, state) do
    {:noreply, handle(connection, message, state)}
  end



  defp handle(connection, message, state) do
    try do
      case Protocol.decode(message) do
        %DataMessage{type: 25} = msg ->
          Connection.send(connection, message)
          state
        %DataMessage{type: 20, headers: [topic_headers]} = msg ->
          Logger.debug "Topic load msg #{inspect msg}"

          # todo: this needs to be more elegant
          case :binary.split(topic_headers, "!") do
            [topic, topic_alias] ->
              updated_map = Map.put(state.alias_map, "!" <> topic_alias, topic)
              state = Map.put(state, :alias_map, updated_map)
              TopicHandler.handle(topic, :topic_loaded)
              state
            _ ->
              raise {:error, {:malformed_headers, topic_headers}}
          end
        %DataMessage{type: 21, headers: [topic_alias|_tail]} = msg ->

          case Map.get(state.alias_map, topic_alias) do
            nil ->
              Logger.error "Msg unhandled #{inspect msg}"
              state
            topic ->
              TopicHandler.handle(topic, {:topic_delta, msg})
              state
          end
        %DataMessage{} = msg ->
          Logger.info "data msg #{inspect msg}"
          state
        %ConnectionResponse{} ->
          Logger.info "connection response"
          state
        msg ->
          Logger.error "unexpected msg #{inspect msg}"
          state
      end
    rescue
      e in RuntimeError ->
        Logger.error("An error occurred: " <> e.message)
      {:no_reply, state}
    end

  end
end
