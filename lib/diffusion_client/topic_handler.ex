require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.Router

  # todo: check functions exist on the callback?

  use GenServer

  @type state :: any
  @type topic :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, state) :: {:ok, state}


  # Client API
  def start_link(args) do
    Logger.debug "start_link topic handler [#{inspect args}]"
    GenServer.start_link(__MODULE__, args |> Enum.into(%{}), [])
  end

  # Server callbacks
  def init(%{topic: topic, callback: callback} = args) do
    Logger.debug "Started topic handler [#{inspect args}]"
    Router.subscribe(topic)
    {:ok, args}
  end

  def handle_cast({:topic_loaded, topic_alias}, %{owner: owner, topic: topic, callback: callback} = state) do
    Logger.info "Topic loaded: #{inspect topic}"
    Router.subscribe(topic_alias)
    send owner, {:topic_loaded, topic}
    {:ok, callback_state} = callback.topic_init(topic)
    {:noreply, Map.put(state, :callback_state, callback_state)}
  end

  def handle_cast({:topic_delta, msg}, %{topic: topic, callback: callback, callback_state: callback_state} = state) do
    {:ok, callback_state} = callback.topic_delta(topic, msg, callback_state)
    {:noreply, Map.put(state, :callback_state, callback_state)}
  end
end
