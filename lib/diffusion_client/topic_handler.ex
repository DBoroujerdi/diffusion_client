require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.{Util, TopicHandlerSup, Connection}
  alias Diffusion.Websocket.Protocol
  alias Protocol.DataMessage


  use GenServer

  @type state :: any
  @type topic :: String.t
  @type delta :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, delta, state) :: {:ok, state}


  def handle(message) do
    case to_event(message) do
      {:no_handler, error} ->
        Logger.error "no handler for #{inspect error}"
      event ->
        Logger.debug "#{inspect event} -> #{inspect message}"
        :gproc_ps.publish(:l, event, message)
    end
  end

  # todo: a topic handler should timeout and die if no message has been recieved for a configurable time

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)


      @doc """
      Subscribe to topic delta stream.

      todo: command should be a proper data type here.
      todo: should return an erro case if subscription was not possible for some
      reason. maybe the topic doesn't exist
      todo: type spec
      """

      def new(connection, topic, timeout \\ 5000) do
        owner = self()
        worker = Supervisor.Spec.worker(__MODULE__, [[topic: topic, connection: connection, owner: owner]], [id: topic, restart: :permanent])

        case Supervisor.start_child(TopicHandlerSup.via(connection.host), worker) do
          {:ok, child} ->
            bin = Protocol.encode(%DataMessage{type: 22, headers: [topic]})
            case Connection.send_data_sync(connection.via, bin, {:topic_loaded, topic}) do
              {:error, reason} ->
                Supervisor.terminate_child(TopicHandlerSup.via(connection.host), child)
              ok -> ok
            end
          error -> error
        end
      end

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
      end

      # todo: a topic handler should be able to resubscribe via the connection if the connection has restarted and
      # the subscriptions have not been preserved on reconnection

      def init(args) do
        owner = Keyword.get(args, :owner)
        topic = Keyword.get(args, :topic)
        # todo: take out connetion and pass that in. we'll use that to link to the connection

        Logger.debug "initing handler for topic #{inspect topic}"
        :gproc_ps.subscribe(:l, {:topic_message, topic})
        {:ok, %{topic: topic, owner: owner, callback_state: %{}}}
      end


      def handle_info({:gproc_ps_event, {:topic_message, _}, message}, state) do
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
      end


      defp handle_message(message, state) do
        Logger.debug "message #{inspect message}"

        case message do
          %DataMessage{type: 20, headers: [topic_headers]} ->
            # todo: duplicate code: see below
            case Util.split(topic_headers) do
              [topic, topic_alias] ->
                :gproc_ps.subscribe(:l, {:topic_message, topic_alias})
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


  ##

  defp to_event(message) do
    case message do
      %DataMessage{type: 20, headers: [topic_headers]} ->
        # todo: splitting the headers appart should really be a concern of the Protocol
        # would prefer if i could do something like headers.alias and headers.topic
        case Util.split(topic_headers) do
          [topic, _] ->
            {:topic_message, topic}
          _ ->
            {:error, message}
        end
      %DataMessage{type: 21, headers: [topic_alias|_]} ->
        {:topic_message, topic_alias}
      _ ->
        {:error, message}
    end
  end
end
