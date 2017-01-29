require Logger

defmodule Diffusion.Router do
  alias Diffusion.Connection
  alias Diffusion.Websocket.Protocol
  alias Protocol.{DataMessage, ConnectionResponse}


  @moduledoc """
  Decodes and routes diffusion messages recieved from the connection
  to the appropriate topic handler.
  """

  # toodo: should protocol decoding and routing be decoupled here?

  # todo: are topic aliases removed for topics we are no longer listening to?

  # todo: this should be functional. route should convert a decode value into a spec to be routed to

  def subscribe(key) do
    Logger.debug "#{inspect self()}: subscribing for events #{inspect key}"
    :gproc.reg({:p, :l, {:topic_event, key}})
  end


  ##

  def route(bin) do
    case Protocol.decode(bin) do
      %DataMessage{type: 25} ->
        Connection.send_data(self(), Protocol.encode(bin))
      %DataMessage{type: 20, headers: [topic_headers]} = msg ->
        Logger.debug "Topic load msg #{inspect msg}"

        # todo: splitting the headers appart should really be a concern of the Protocol
        case split(topic_headers) do
          [topic, topic_alias] ->
            GenServer.cast({:via, :gproc, {:p, :l, {:topic_event, topic}}}, {:topic_loaded, topic_alias})
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


  defp split(string) do
    case :binary.split(string, "!") do
      [left, right] ->
        [left, "!" <> right]
      _ ->
        :error
    end
  end
end
