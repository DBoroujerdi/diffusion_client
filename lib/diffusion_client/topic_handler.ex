require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.{TopicHandlerSup, Connection}
  alias Diffusion.Websocket.Protocol
  alias Protocol.{Delta, TopicLoad, Message}


  use GenServer

  @type state :: any
  @type topic :: String.t
  @type delta :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, delta, state) :: {:ok, state}


  def handle(message) do
    case to_event(message) do
      :nil ->
        Logger.error "unable to convert to event: #{inspect message}"
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

        case TopicHandlerSup.start_child(connection, worker) do
          {:ok, child} ->
            receive do
              {:topic_loaded, ^topic} -> :ok
              other -> {:error, {:unexpected_message, other}}
            after timeout
                -> TopicHandlerSup.stop_child(connection, child)
              {:error, :timeout}
            end
          error -> error
        end
      end

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
      end


      def init(args) do
        owner = Keyword.get(args, :owner)
        topic = Keyword.get(args, :topic)
        connection = Keyword.get(args, :connection)

        Logger.debug "initing handler for topic #{inspect topic}"
        :gproc_ps.subscribe(:l, {:topic_message, topic})

        send self(), :init

        Process.monitor(:gproc.lookup_pid(connection.aka))

        {:ok, %{connection: connection, topic: topic, owner: owner, callback_state: %{}}}
      end


      def handle_info({:DOWN, _, :process, _, _}, state) do
        Logger.error "Connection is down! restarting handler"
        exit(:connection_down)
      end

      def handle_info(:init, state) do
        Logger.debug "initializing topic handler.."
        bin = Protocol.encode(%Message{type: 22, headers: [state.topic]})
        :ok = Connection.send_data(state.connection.aka, bin)
        {:noreply, state}
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
          %TopicLoad{topic: topic, topic_alias: topic_alias} ->
            :gproc_ps.subscribe(:l, {:topic_message, topic_alias})
            send state.owner, {:topic_loaded, topic}
            __MODULE__.topic_init(topic)
          %Delta{} ->
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
      %TopicLoad{topic: topic} ->
        {:topic_message, topic}
      %Delta{topic_alias: topic_alias} ->
        {:topic_message, topic_alias}
      _ ->
        :nil
    end
  end
end
