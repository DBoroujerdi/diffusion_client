require Logger

defmodule Diffusion.Client do
  use Application

  alias Diffusion.{Connection, ConnectionSup, TopicHandlerSup}
  alias Diffusion.Websocket.Protocol
  alias Protocol.DataMessage


  # API functions

  @doc """
  Connect to diffusion server at host:port/path. Initiates connection and returns
  a session struct representing the session. This session should be used
  in all interactions with the client.
  """

  @spec connect(String.t, number, opts) :: {:ok, pid} | {:error, any} when opts: [atom: any]

  def connect(host, port \\ 80, path, timeout \\ 5000, opts \\ []) do
    Logger.info "connecting..."

    with {:ok, pid} <- ConnectionSup.new_connection(host, opts),
         :valid <- validate_opts(opts)
      do Connection.connect(pid, host, port, path, timeout, opts)
      else
        error -> error
    end
  end


  @doc """
  Subscribe to topic delta stream.

  todo: command should be a proper data type here.
  todo: should return an erro case if subscription was not possible for some
  reason. maybe the topic doesn't exist
  """

  # todo: can a module callback be typed??

  @spec add_topic(pid, binary, module, pos_integer) :: :ok | {:error, any}

  def add_topic(connection, topic, callback, timeout \\ 5000) do
    Logger.info "Adding topic to #{inspect topic} with callback #{inspect callback}"

    if Process.alive?(connection) do
      case TopicHandlerSup.new_handler(topic, self(), callback) do
        {:ok, _} ->
          bin = Protocol.encode(%DataMessage{type: 22, headers: [topic]})
          Connection.send(connection, bin)
          receive do
            {:topic_loaded, topic} -> :ok
            other -> {:error, {:unexpected_message, other}}
          after timeout
            -> {:error, :timeout}
          end
        error -> error
      end
    else
      {:error, :connection_down}
    end
  end


  @spec send(pid, DataMessage.t) :: :ok | {:error, :connection_down}

  def send(connection, data) do
    if Process.alive?(connection) do
      Connection.send(connection, Protocol.encode(data))
    else
      {:error, :connection_down}
    end
  end


  @doc """
  Close a connection. All topic subscriptions consuming from the connection
  will also close as a result.
  """

  @spec close_session(pid) :: :ok | {:error, any}

  def close_session(connection) do
    if Process.alive?(connection) do
      ConnectionSup.stop_child(connection)
      # todo: close all topic subscriptions as well.
    else
      {:error, :no_connection}
    end
  end


  @spec start() :: {:ok, [atom]} | {:error, {atom, term}}

  def start() do
    Application.ensure_all_started(__MODULE__)
  end


  def start(_, _) do
    Logger.info "Starting DiffusionClient"

    # todo: support starting connection and subscriptions
    # from config

    Diffusion.Supervisor.start_link()
  end

  ##
  ## Private
  ##

  defp validate_opts(_opts) do
    # todo: implement validation
    :valid
  end

end
