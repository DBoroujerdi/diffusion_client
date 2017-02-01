require Logger

defmodule Diffusion.TopicHandler do
  alias Diffusion.Connection
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

      def start_link(connection, topic) do
        GenServer.start_link(__MODULE__, [topic: topic, connection: connection], name: via({connection.host, topic}))
      end

      defp via(name) do
        {:via, :gproc, {:n, :l, {__MODULE__, name}}}
      end

      def init(args) do
        Logger.debug "initing with args #{inspect args}"

        topic = Keyword.get(args, :topic)
        connection = Keyword.get(args, :connection)

        Logger.debug "initing handler for topic #{inspect topic}"
        :gproc_ps.subscribe(:l, {:topic_message, topic})

        send self(), :init

        connection_pid = :gproc.lookup_pid(connection.aka)
        if Process.alive?(connection_pid) do
          Process.monitor(:gproc.lookup_pid(connection.aka))
          {:ok, %{connection: connection, topic: topic, callback_state: %{}}}
        else
          {:stop, :connection_down}
        end
      end

      # todo: timeout waiting for topic to load

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
