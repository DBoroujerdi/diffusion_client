require Logger

defmodule Diffusion.ConnectionSup do
  alias Diffusion.Connection

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
  alias Diffusion.{TopicHandler, Websocket}
  alias Diffusion.Websocket.Protocol
  alias Protocol.Ping

  use GenServer

  @type conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number} | {:owner, pid}


  # API

  @spec start_link(opts) :: GenServer.on_start when opts: [{:id, String.t}]

  def start_link(opts) do
    Logger.info "#{inspect opts}"
    GenServer.start_link(__MODULE__, opts)
  end


  @spec alive?(pid) :: boolean

  def alive?(pid) do
    Process.alive?(pid)
  end


  @spec close(pid) :: :ok

  def close(pid) do
    Logger.debug "closing connection.."
    GenServer.stop(pid)
  end


  @spec send_data(identifier, String.t) :: :ok when identifier: tuple | pid

  def send_data(pid, data) when is_binary(data) do
    GenServer.cast(pid, {:send, data})
  end


  # callbacks

  def init(opts) do
    Process.flag(:trap_exit, true)
    Logger.debug "consumer opts #{inspect opts}"

    send self(), :connect

    {:ok, opts}
  end


  def handle_info(:connect, state) do
    {:noreply, connect(state)}
  end


  def handle_info({:DOWN, mref, :process, _, _reason}, %{mref: mref} = state) do
    {:noreply, connect(state)}
  end

  def handle_info({:gun_down, _, :ws, :closed, _, _}, state) do
    {:noreply, connect(state)}
  end

  def handle_info({:gun_ws, _, {:text, data}}, state) do
    Logger.debug data

    case Protocol.decode(data) do
      {:error, reason} ->
        Logger.error "error decoding #{inspect reason}"
      %Ping{} = ping ->
        TopicHandler.publish(state.host, ping)
        Websocket.send(state.socket, data)
      decoded ->
        TopicHandler.publish(state.host, decoded)
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
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
    Logger.info "closing socket"
    case Websocket.close(state.socket) do
      :ok ->
        Logger.debug "Connection closed"
      error ->
        Logger.error "Unable to close connection: #{inspect error}"
    end
    :shutdown
  end

  def terminate(_reason, _state) do
    :shutdown
  end

  #

  defp connect(state) do
    case Websocket.open(state) do
      {:ok, socket} ->
        new_state = %{mref: Process.monitor(socket), socket: socket}
        # todo: notify handlers via event bus
        send state.owner, {:started, self()}
        Map.merge(state, new_state)
      error ->
        exit(error)
    end
  end
end
