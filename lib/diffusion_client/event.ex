defmodule Diffusion.Event do
  alias Diffusion.Websocket.Protocol
  alias Protocol.{Delta, TopicLoad, ConnectionResponse, Ping}

  # todo: doc to describe what this module does

  @type t :: topic_message_event | reconnection_event

  @type topic_message_event :: {:topic_message, Protocol.message}
  @type reconnection_event :: :diffusion_reconnection

  def event_type_for(message) do
    case message do
      %TopicLoad{topic: topic} ->
        {:diffusion_topic_message, topic}
      %Delta{topic_alias: topic_alias} ->
        {:diffusion_topic_message, topic_alias}
      %ConnectionResponse{} ->
        :diffusion_reconnection
      %Ping{} ->
        :diffusion_ping
      _ ->
        :nil
    end
  end
end
