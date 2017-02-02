defmodule Diffusion.EventBusTest do
  alias Diffusion.EventBus
  alias Diffusion.Websocket.Protocol

  use ExSpec
  doctest Diffusion.EventBus

  describe "pubsub" do
    it "noitifies me of event I subscribe to" do
      :ok = EventBus.subscribe(:foo_event)

      :ok = EventBus.publish(:foo_event, "bar_message")

      receive do
        {:diffusion_event, :foo_event, msg} -> assert msg == "bar_message"
      after 1000
          -> assert false
      end
    end

  end

  describe "sync receiving pubsub" do
    it "receives published message" do
      :ok = EventBus.subscribe(:foo_event)
      :ok = EventBus.publish(:foo_event, "bar_message")

      assert EventBus.receive_event(:foo_event) == "bar_message"
    end

    it "times out if no message received" do
      assert EventBus.receive_event(:foo_timeout_event) == :timeout
    end
  end
end
