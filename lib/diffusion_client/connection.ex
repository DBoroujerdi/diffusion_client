require Logger

defmodule Diffusion.ConnectionSup do
  alias Diffusion.{Connection}

  use Supervisor


  @spec start_link(map) :: Supervisor.on_start

  def start_link(%{host: host} = config) do
    Supervisor.start_link(__MODULE__, config, name: via(host))
  end


  def via(name) do
    {:via, :gproc, key(name)}
  end

  def key(name) do
    {:n, :l, {__MODULE__, name}}
  end


  def init(config) do
    Logger.debug "Connection supervisor started."

    child_spec = worker(Connection, [config])

    supervise([child_spec], strategy: :one_for_one, restart: :permanent)
  end
end


defmodule Diffusion.Connection do
  alias Diffusion.{Connection, TopicHandler, Websocket}
  alias Diffusion.Websocket.Protocol
  alias Protocol.Ping

  use GenServer

  @type t :: %Connection{aka: tuple, host: String.t, path: String.t}

  defstruct [:aka, :host, :host, :path]

  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number} | {:owner, pid}


  # API

  @spec start_link(opts) :: GenServer.on_start when opts: [{:id, String.t}]

  def start_link(%{host: host} = opts) do
    Logger.info "#{inspect opts}"
    GenServer.start_link(__MODULE__, opts, name: via(host))
  end


  def via(name) do
    {:via, :gproc, key(name)}
  end

  def key(name) do
    {:n, :l, {__MODULE__, name}}
  end


  @spec new(binary, number, binary, pos_integer, opts) :: {:ok, pid} | {:error, any}
        when opts: [{atom, any}]

  def new(host, port, path, timeout, opts) do
    config = opts ++ [host: host, port: port, path: path, timeout: timeout, owner: self()]
    |> Enum.into(%{})

    case Diffusion.Supervisor.start_child(config) do
      {:ok, pid} ->
        receive do
          {:connected, connection} ->
            {:ok, connection}
          error ->
            Diffusion.Supervisor.stop_child(pid)
            error
        after timeout
            -> {:error, :timeout}
        end
      error -> error
    end
  end


  @spec alive?(Connection.t) :: boolean

  def alive?(connection) do
    Process.alive?(:gproc.lookup_pid(connection.aka))
  end

  def close(connection) do
    # todo: is this enough?
    send {:via, :gproc, connection.aka}, :kill
  end


  @spec send_data(identifier, String.t) :: :ok when identifier: tuple | pid

  def send_data({:n, :l, _} = key, data) when is_binary(data) do
    GenServer.cast({:via, :gproc, key}, {:send, data})
  end


  # callbacks

  ##

  def init(opts) do
    Process.flag(:trap_exit, true)
    Logger.debug "session opts #{inspect opts}"

    send self(), :connect

    {:ok, opts}
  end

  ##

  def handle_info(:connect, %{host: host, path: path} = state) do
    case Websocket.open_websocket(state) do
      {:ok, socket} ->
        connection = %Connection{aka: key(host), host: host, path: path}
        new_state = %{mref: Process.monitor(socket), socket: socket, connection: connection}
        send state.owner, {:connected, connection}
        {:noreply, Map.merge(state, new_state)}
      error ->
        send state.owner, error
        {:noreply, state}
    end
  end


  def handle_info({:DOWN, mref, :process, _, reason}, %{mref: mref}) do
    exit({:connection_process_down, reason})
  end

  def handle_info({:gun_down, _, :ws, :closed, _, _}, _) do
    exit({:connection_process_down, "monitor down"})
  end

  def handle_info({:gun_ws, _, {:text, data}}, state) do
    Logger.debug data

    case Protocol.decode(data) do
      {:error, reason} ->
        Logger.error "error decoding #{inspect reason}"
      %Ping{} ->
        Websocket.send(state.socket, data)
      decoded ->
        TopicHandler.handle(state.connection, decoded)
    end

    {:noreply, state}
  end


  ##

  def handle_cast({:send, data}, state) when is_binary(data) do
    :ok = Websocket.send(state.socket, data)
    {:noreply, state}
  end



  def terminate({:connection_process_down, _}, _) do
    :shutdown
  end

  def terminate(:shutdown, state) do
    case Websocket.close(state.socket) do
      :ok ->
        Logger.debug "Connection closed"
      error ->
        Logger.error "Unable to close connection: #{inspect error}"
    end
    :shutdown
  end
end
