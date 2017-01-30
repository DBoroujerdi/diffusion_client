require Logger

defmodule Diffusion.Client do
  use Application

  alias Diffusion.Connection
  alias Diffusion.Websocket.Protocol
  alias Protocol.DataMessage


  # API functions

  @doc """
  Connect to diffusion server at host:port/path. Initiates connection and returns
  a session struct representing the session. This session should be used
  in all interactions with the client.
  """

  @spec connect(String.t, number, String.t, opts) :: {:ok, Connection.t} | {:error, any} when opts: [atom: any]

  def connect(host, port \\ 80, path, timeout \\ 5000, opts \\ []) do
    Logger.info "connecting..."

    case validate_opts(opts) do
      :valid ->
        Connection.new(host, port, path, timeout, opts)
      error ->
        error
    end
  end



  @spec send(Connection.t, DataMessage.t) :: :ok | {:error, :connection_down}

  def send(connection, data) do
    if Process.alive?(connection.via) do
      Connection.send_data(connection.via, Protocol.encode(data))
    else
      {:error, :connection_down}
    end
  end


  @doc """
  Close a connection. All topic subscriptions consuming from the connection
  will also close as a result.
  """

  @spec close_connection(Connection.t) :: :ok | {:error, any}

  def close_connection(connection) do
    if Process.alive?(connection.via) do
      Diffusion.Supervisor.stop_child(connection)
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
