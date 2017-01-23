require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.Router

  use GenServer

  # Client API
  def start_link(args) do
    Logger.debug "start_link topic handler [#{inspect args}]"
    GenServer.start_link(__MODULE__, args |> Enum.into(%{}), [])
  end

  def handle(topic, event) do
    GenServer.cast({:via, :gproc, {:p, :l, {:topic_event, topic}}}, event)
  end

  # Server callbacks
  def init(%{topic: topic} = args) do
    Logger.debug "Started topic handler [#{inspect args}]"
    Router.subscribe(topic)
    {:ok, args}
  end

  def handle_cast({:topic_loaded, topic_alias}, %{owner: owner, topic: topic} = state) do
    Logger.info "Topic loaded: #{inspect topic}"
    Router.subscribe(topic_alias)
    send owner, {:topic_loaded, topic}
    {:noreply, state}
  end

  def handle_cast({:topic_delta, msg}, %{topic: topic} = state) do
    Logger.debug "#{inspect self()} DELTA -->  #{inspect topic}: #{inspect msg}"
    # todo: send to callback module
    {:noreply, state}
  end
end
