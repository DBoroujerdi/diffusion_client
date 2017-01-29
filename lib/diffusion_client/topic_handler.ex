require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.{Client, Util}
  alias Diffusion.Websocket.Protocol.DataMessage


  use GenServer

  @type state :: any
  @type topic :: String.t
  @type delta :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, delta, state) :: {:ok, state}


  def handle(message) do
    case via_for(message) do
      {:no_handler, error} ->
        Logger.error "no handler for #{inspect error}"
      via ->
        Logger.debug "#{inspect via}"
        GenServer.cast(via, {:topic_message, message})
    end
  end

  # todo: a topic handler should timeout and die if no message has been recieved for a configurable time

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def new(connection, topic, timeout \\ 5000) do
        Client.add_topic(connection, topic, __MODULE__, timeout)
      end

      def start_link(args) do
        GenServer.start_link(__MODULE__, args |> Enum.into(%{}), [])
      end

      # todo: a topic handler should be able to resubscribe via the connection if the connection has restarted and
      # the subscriptions have not been preserved on reconnection

      def init(args) do
        :gproc.reg({:p, :l, {:topic_message, args.topic}})
        {:ok, args}
      end


      def handle_cast({:topic_message, message}, state) do
        Logger.debug "handling #{inspect message}"
        case handle_message(message, state) do
          {:ok, callback_state} ->
            {:noreply, Map.put(state, :callback_state, callback_state)}
          :unhandled ->
            {:noreply, state}
        end
      end


      defp handle_message(message, state) do
        Logger.debug "message #{inspect message}"

        case message do
          %DataMessage{type: 20, headers: [topic_headers]} ->
            case Util.split(topic_headers) do
              [topic, topic_alias] ->
                :gproc.reg({:p, :l, {:topic_message, topic_alias}})
              _ ->
                :ok
            end
            send state.owner, {:topic_loaded, state.topic}
            __MODULE__.topic_init(state.topic)
          %DataMessage{type: 21} ->
            __MODULE__.topic_delta(state.topic, message, state.callback_state)
          _ ->
            :unhandled
        end
      end
    end
  end


  defp via_for(message) do
    case message do
      %DataMessage{type: 20, headers: [topic_headers]} ->
        # todo: splitting the headers appart should really be a concern of the Protocol
        # would prefer if i could do something like headers.alias and headers.topic
        case Util.split(topic_headers) do
          [topic, _] ->
            {:via, :gproc, {:p, :l, {:topic_message, topic}}}
          _ ->
            {:no_handler, message}
        end
      %DataMessage{type: 21, headers: [topic_alias|_]} ->
        {:via, :gproc, {:p, :l, {:topic_message, topic_alias}}}
      _ ->
        {:no_handler, message}
    end
  end
end
