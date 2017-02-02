defmodule Diffusion.EventTest do
  alias Diffusion.Event
  alias Diffusion.Websocket.Protocol
  alias Protocol.{ConnectionResponse, Message, TopicLoad, Delta, Ping}

  use ExSpec
  doctest Diffusion.Websocket.Protocol

  describe "events" do

    it "returns event term for TopicLoad msg" do
      assert Event.event_type_for(%TopicLoad{topic: "topic_name"}) == {:diffusion_topic_message, "topic_name"}
    end

    it "returns event term for Delta msg" do
      assert Event.event_type_for(%Delta{topic_alias: "topic_alias"}) == {:diffusion_topic_message, "topic_alias"}
    end

    it "returns event term for ConnectionResponse msg" do
      assert Event.event_type_for(%ConnectionResponse{}) == :diffusion_reconnection
    end

    it "returns event term for Ping msg" do
      assert Event.event_type_for(%Ping{}) == :diffusion_ping
    end

    it "returns :nil for anything else" do
      assert Event.event_type_for("garbage") == :nil
      assert Event.event_type_for(:lamp) == :nil
      assert Event.event_type_for(42) == :nil
      assert Event.event_type_for({:foo, :bar, :baz}) == :nil
    end
  end
end
