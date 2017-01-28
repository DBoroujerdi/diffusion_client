defmodule Diffusion.TopicHandler do
  alias Diffusion.{Router, Client}


  use GenServer

  @type state :: any
  @type topic :: String.t
  @type delta :: String.t

  @callback topic_init(topic) :: state
  @callback topic_delta(topic, delta, state) :: {:ok, state}

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

      def init(%{topic: topic} = args) do
        Router.subscribe(topic)
        {:ok, args}
      end

      def handle_cast({:topic_loaded, topic_alias}, %{owner: owner, topic: topic} = state) do
        Router.subscribe(topic_alias)
        send owner, {:topic_loaded, topic}
        {:ok, callback_state} = __MODULE__.topic_init(topic)
        {:noreply, Map.put(state, :callback_state, callback_state)}
      end

      def handle_cast({:topic_delta, msg}, %{topic: topic, callback_state: callback_state} = state) do
        {:ok, callback_state} = __MODULE__.topic_delta(topic, msg, callback_state)
        {:noreply, Map.put(state, :callback_state, callback_state)}
      end
    end
  end
end
