require Logger

defmodule Diffusion.Handler do
  alias Diffusion.{Session, TopicMappings}
  alias Diffusion.Websocket.Protocol, as: Protocol
  alias Session.State
  alias Protocol.{DataMessage, ConnectionResponse}

  @spec handle_msg(Session.t, binary, Session.state) :: :ok

  # todo: look to be building a bunch of handling strategies for the different
  # types of messages - these should be extracted out at some point into a
  # a bunch of functions for each, then this genereal handle_msg function can itself
  # unit tested.

  def handle_msg(session, data, state) do
    case Protocol.decode(data) do
      %DataMessage{type: 25} = msg ->
        Session.send(session, msg)
        state
      %DataMessage{type: 20, headers: [topic_headers]} = msg ->
        Logger.info "Topic load msg #{inspect msg}"

        # todo: this needs to be more elegant
        case :binary.split(topic_headers, "!") do
          [topic, topic_alias] ->
            updated_mappings = TopicMappings.add_topic_alias(state.topic_mappings, "!" <> topic_alias, topic)
            Logger.info("#{inspect state.topic_mappings}")
            state = State.update_mappings(state, updated_mappings)
            send state.owner, {:topic_loaded, topic}
            state
          _ ->
            raise {:error, {:malformed_headers, topic_headers}}
        end
      %DataMessage{type: 21, headers: [topic_alias|_tail]} = msg ->

        case TopicMappings.get(state.topic_mappings, :alias, topic_alias) do
          nil ->
            Logger.error "Msg unhandled #{inspect msg}"
            state
          handler ->
            handler.handle(msg)
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
  end
end
