require Logger

defmodule Diffusion.TopicHandler do
  use GenServer

  # Client API
  def start_link(args) do
    Logger.debug "start_link topic handler [#{inspect args}]"
    GenServer.start_link(__MODULE__, args, [])
  end

  def handle(topic, event) do
    GenServer.cast({:via, :gproc, {:p, :l, {:topic_event, topic}}}, event)
  end

  # Server callbacks
  def init(args) do
    Logger.debug "Started topic handler [#{inspect args}]"

    case List.keyfind(args, :topic, 0) do
      nil ->
        {:stop, "missing topic arg"}
      {:topic, topic} ->
        Logger.debug "Registering for topic events for #{inspect topic}"
        :gproc.reg({:p, :l, {:topic_event, topic}})
        {:ok, args |> Enum.into(%{})}
    end
  end

  def handle_cast({:topic_loaded, topic_alias}, %{owner: owner, topic: topic} = state) do
    Logger.info "Topic loaded: #{inspect topic}"
    :gproc.reg({:p, :l, {:topic_event, topic_alias}})
    send owner, {:topic_loaded, topic}
    {:noreply, state}
  end

  def handle_cast({:topic_delta, msg}, %{topic: topic} = state) do
    Logger.debug "#{inspect self()} DELTA -->  #{inspect topic}: #{inspect msg}"
    # todo: send to callback module
    {:noreply, state}
  end
end
