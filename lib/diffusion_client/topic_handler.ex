require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.{Session, Event, EventBus}
  alias Diffusion.Websocket.Protocol
  alias Protocol.{Delta, TopicLoad, Message, Ping, ConnectionResponse}


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

      def start_link(session, topic, opts \\ []) do
        GenServer.start_link(__MODULE__, [topic: topic, session: session], name: via({session.host, topic}))
      end

      defp via(name) do
        {:via, :gproc, {:n, :l, {__MODULE__, name}}}
      end

      def init(args) do
        topic   = Keyword.get(args, :topic)
        session = Keyword.get(args, :session)
        timeout = Keyword.get(args, :timeout, 5 * 60 * 1000)

        Logger.debug "initing handler for topic #{inspect topic}"

        :ok = EventBus.subscribe([
          {:diffusion_topic_message, topic},
          {:diffusion_event, session.host}
        ])

        send self(), :subscribe

        if Session.alive?(session) do
          Process.monitor(session.aka)
          {:ok, %{session: session, topic: topic, timeout: timeout, callback_state: %{}}}
        else
          {:stop, :session_down}
        end
      end


      def handle_info(:timeout, state) do
        Logger.warn "Handler timed out"
        exit(:diffusion_timeout)
      end

      def handle_info({:DOWN, _, :process, _, _}, state) do
        Logger.warn "Session down"
        exit(:diffusion_session_down)
      end

      def handle_info(:subscribe, state) do
        {:noreply, subscribe(state)}
      end


      def handle_info({:diffusion_event, {:diffusion_event, _}, msg}, state) do
        case msg do
          %Ping{} ->
            {:noreply, state, state.timeout}
          %ConnectionResponse{} ->
            Logger.debug "diffusion connected"
            {:noreply, subscribe(state), state.timeout}
        end
      end


      def handle_info({:diffusion_event, {:diffusion_topic_message, _}, message}, state) do
        Logger.debug "handling #{inspect message}"
        case handle_message(message, state) do
          {:ok, callback_state} ->
            {:noreply, Map.put(state, :callback_state, callback_state), state.timeout}
          :unhandled ->
            {:noreply, state, state.timeout}
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

      defp subscribe(state) do
        Logger.debug "initializing topic subscription.."
        bin = Protocol.encode(%Message{type: 22, headers: [state.topic]})
        # todo rename to add_topic
        :ok = Session.send_data(state.session.aka, bin)
        state
      end
    end
  end


  def publish(host, message) do
    event = case message do
              %TopicLoad{topic: topic} ->
                {:diffusion_topic_message, topic}
              %Delta{topic_alias: topic_alias} ->
                {:diffusion_topic_message, topic_alias}
              _ ->
                {:diffusion_event, host}
            end

    Logger.debug "#{inspect event} -> #{inspect message}"
    EventBus.publish(event, message)
  end
end
