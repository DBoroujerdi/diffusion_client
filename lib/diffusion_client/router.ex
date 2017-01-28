require Logger

defmodule Diffusion.Router do
  alias Diffusion.Connection
  alias Diffusion.Websocket.Protocol
  alias Protocol.{DataMessage, ConnectionResponse}

  @moduledoc """
  Decodes and routes diffusion messages recieved from the connection
  to the appropriate topic handler.
  """


  def route(bin) when is_binary(bin) do
    # todo: will this try block actually catch any error?
    try do
      Protocol.decode(bin) |> maybe_route()
    rescue
      e in RuntimeError ->
        Logger.error("An error occurred: " <> e.message)
    end

    :ok
  end

  def subscribe(key) do
    Logger.debug "#{inspect self()}: subscribing for events #{inspect key}"
    :gproc.reg({:p, :l, {:topic_event, key}})
  end

  # Server callbacks
  def init(:ok) do
    {:ok, :ok}
  end


  defp maybe_route(message) do
    case message do
      %DataMessage{type: 25} ->
        Connection.send_data(self(), Protocol.encode(message))
      %DataMessage{type: 20, headers: [topic_headers]} = msg ->
        Logger.debug "Topic load msg #{inspect msg}"

        # todo: this needs to be more elegant
        case :binary.split(topic_headers, "!") do
          [topic, topic_alias] ->
            GenServer.cast({:via, :gproc, {:p, :l, {:topic_event, topic}}}, {:topic_loaded, "!" <> topic_alias})
          _ ->
            Logger.error "error parsing headers [#{inspect topic_headers}]"
        end
      %DataMessage{type: 21, headers: [topic_alias|_tail]} = msg ->
        GenServer.cast({:via, :gproc, {:p, :l, {:topic_event, topic_alias}}}, {:topic_delta, msg})
      %DataMessage{} = msg ->
        Logger.debug "data msg #{inspect msg}"
      %ConnectionResponse{} ->
        Logger.debug "connection response"
      msg ->
        Logger.error "unexpected msg #{inspect msg}"
    end
  end
end
