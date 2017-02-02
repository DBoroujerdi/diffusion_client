defmodule Diffusion.EventBus do
  alias Diffusion.Event
  alias Diffusion.Websocket.Protocol


  @doc """
  Subscribe to an event of type Event.t or a list of Event.t.

  ## Example
      EventBus.subscribe({:diffusion_topic_message, "topic_name"})
      EventBus.subscribe(:diffusion_ping_event)
  """

  @spec subscribe(event) :: :ok when event: Event.t | [Event.t]

  def subscribe(events) when is_list(events) do
    _ = Enum.each(events, &subscribe(&1))
    :ok
  end

  def subscribe(event) do
    try do
      do_subscribe(event)
    rescue
      _ -> :ok # already subbed
    end
  end

  defp do_subscribe(event) do
    :gproc.reg({:p, :l, {:diffusion_event, event}})
    :ok
  end



  @doc """
  Publish a message with event type Event.t.

  Subscribed processes will receive messages published with that event type to their handle_info.

  Received by subscriber as {:diffusion_event, {:diffusion_topic_message, "topic_name"}, message}

  ## Example:
      EventBus.publish({:diffusion_topic_message, "topic_name"}, message)
  """

  @spec publish(Event.t, Protocol.message) :: :ok

  def publish(event, message) do
    try do
      _ = :gproc.send({:p, :l, {:diffusion_event, event}}, {:diffusion_event, event, message})
      :ok
    rescue
      _ -> :ok
    end
  end


  @doc """
  Sync receive a message

  ## Example
       EventBus.publish(:foo_event, "message data")
       EventBus.subscribe(:foo_event)
       EventBus.receive_event(:foo_event)

       todo: example
  """


  @spec receive_event(Event.t) :: Protocol.message

  def receive_event(event_type) do
    receive_event(event_type, 1000)
  end


  @spec receive_event(Event.t, number) :: Protocol.message | :timeout

  def receive_event(event_type, timeout) do
    receive do
      {:diffusion_event, ^event_type, msg} -> msg
    after timeout ->
        :timeout
    end
  end
end
