defmodule Diffusion.EventBusTest do
  alias Diffusion.EventBus

  use ExSpec
  doctest Diffusion.EventBus

  describe "pubsub" do
    it "noitifies me of event I subscribe to" do
      :ok = EventBus.subscribe(:foo_event)

      :ok = EventBus.publish(:foo_event, "bar_message")

      assert_receive({:diffusion_event, :foo_event, "bar_message"}, 1000)
    end

  end

  describe "sync receiving pubsub" do
    it "receives published message" do
      :ok = EventBus.subscribe({:foo_event, "foo"})
      :ok = EventBus.publish({:foo_event, "foo"}, "bar_message")

      assert EventBus.receive_event({:foo_event, "foo"}) == "bar_message"
    end

    it "times out if no message received" do
      assert EventBus.receive_event(:foo_timeout_event) == :timeout
    end
  end
end
