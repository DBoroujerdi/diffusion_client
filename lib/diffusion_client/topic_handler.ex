require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.{Connection, Event, EventBus}
  alias Diffusion.Websocket.Protocol
  alias Protocol.{Delta, TopicLoad, Message}


  use GenServer

  @type state :: any
  @type topic :: String.t
  @type delta :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, delta, state) :: {:ok, state}


  # todo: a topic handler should timeout and die if no message has been recieved for a configurable time

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def start_link(connection, topic, opts \\ []) do
        GenServer.start_link(__MODULE__, [topic: topic, connection: connection], name: via({connection.host, topic}))
      end

      defp via(name) do
        {:via, :gproc, {:n, :l, {__MODULE__, name}}}
      end

      def init(args) do
        topic       = Keyword.get(args, :topic)
        connection  = Keyword.get(args, :connection)
        resub_delay = Keyword.get(args, :resub_delay, 1000)

        Logger.debug "initing handler for topic #{inspect topic}"

        :ok = EventBus.subscribe([
          {:diffusion_topic_message, topic},
          {:diffusion_connection_event, connection.host}
        ])

        send self(), :subscribe

        if Connection.alive?(connection) do
          Process.monitor(:gproc.lookup_pid(connection.aka))
          {:ok, %{connection: connection, topic: topic, resub_delay: resub_delay, callback_state: %{}}}
        else
          {:stop, :connection_down}
        end
      end

      # todo: timeout waiting for topic to load

      def handle_info({:DOWN, _, :process, _, _}, state) do
        Process.send_after(self(), :subscribe, state.resub_delay)
        {:noreply, state}
      end

      def handle_info(:subscribe, state) do
        Logger.debug "initializing topic subscription.."
        bin = Protocol.encode(%Message{type: 22, headers: [state.topic]})
        :ok = Connection.send_data(state.connection.aka, bin)
        {:noreply, state}
      end


      def handle_info({:diffusion_event, :diffusion_reconnection}, message, state) do
        Logger.debug "diffusion reconnection #{inspect message}"
        send self(), :subscribe
        {:noreply, state}
      end


      def handle_info({:diffusion_event, {:diffusion_topic_message, _}, message}, state) do
        Logger.debug "handling #{inspect message}"
        case handle_message(message, state) do
          {:ok, callback_state} ->
            {:noreply, Map.put(state, :callback_state, callback_state)}
          :unhandled ->
            {:noreply, state}
        end
      end

      def terminate(reason, state) do
        :error_logger.error_info(reason)

        :shutdown
      end


      defp handle_message(message, state) do
        Logger.debug "message #{inspect message}"
        case message do
          %TopicLoad{topic: topic, topic_alias: topic_alias} = m ->

            :ok = EventBus.subscribe({:diffusion_topic_message, topic_alias})

            __MODULE__.topic_init(topic)
          %Delta{} ->
            __MODULE__.topic_delta(state.topic, message, state.callback_state)
          _ ->
            :unhandled
        end
      end
    end
  end


  def handle(connection, message) do
    case Event.event_type_for(message) do
      :nil ->
        Logger.error "unable to convert to event: #{inspect message}"
      :reconnection ->
        EventBus.publish({:reconnection, connection.host}, message)
      event ->
        Logger.debug "#{inspect event} -> #{inspect message}"
        EventBus.publish(event, message)
    end
  end
end
