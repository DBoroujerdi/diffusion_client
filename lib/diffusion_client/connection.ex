require Logger

defmodule Diffusion.Connection do
  alias Diffusion.{Connection, TopicHandler, Websocket}
  alias Diffusion.Websocket.Protocol
  alias Protocol.DataMessage

  use GenServer

  @type t :: %Connection{via: tuple, host: String.t, path: String.t}

  defstruct [:via, :host, :host, :path]

  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number} | {:owner, pid}


  # API

  @spec start_link(opts) :: GenServer.on_start when opts: [{:id, String.t}]

  def start_link(%{host: host} = opts) do
    Logger.info "#{inspect opts}"
    GenServer.start_link(__MODULE__, opts, name: via(host))
  end


  def via(name) do
    {:via, :gproc, {:n, :l, {__MODULE__, name}}}
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


  def close(connection) do
    # todo: is this enough?
    send connection.via, :kill
  end


  @spec send_data(identifier, String.t) :: :ok when identifier: tuple | pid

  def send_data(via, data) when is_binary(data) do
    GenServer.cast(via, {:send, data})
  end


  # callbacks

  ##

  def init(opts) do
    # Process.flag(:trap_exit, true)
    Logger.debug "session opts #{inspect opts}"

    send self(), :connect

    {:ok, opts}
  end

  ##

  def handle_info(:connect, %{owner: owner, host: host, path: path} = state) do
    case Websocket.open_websocket(state) do
      {:ok, connection} ->
        new_state = %{mref: Process.monitor(connection), connection: connection}
        send owner, {:connected, %Connection{via: self(), host: host, path: path}}
        {:noreply, Map.merge(state, new_state)}
      error ->
        send owner, error
        {:noreply, state}
    end
  end


  def handle_info({:DOWN, mref, :process, _, reason}, %{mref: mref} = state) do
    {:stop, {:connection_down, reason}, state}
  end

  def handle_info({:gun_down, _, :ws, :closed, _, _}, state) do
    {:stop, :websocket_down, state}
  end

  def handle_info({:gun_ws, _, {:text, data}}, state) do
    case Protocol.decode(data) do
      {:error, reason} ->
        Logger.error "error decoding #{inspect reason}"
      %DataMessage{type: 25} ->
        Websocket.send(state.connection, data)
      decoded ->
        TopicHandler.handle(decoded)
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn "Unexpected msg #{inspect msg}"
    {:noreply, state}
  end


  ##



  ##

  def handle_cast({:send, data}, %{connection: connection} = state) when is_binary(data) do
    :ok = Websocket.send(connection, data)
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.info "Unexpected msg #{msg}"
    {:noreply, state}
  end



  def terminate(_reason, %{connection: connection} = state) do
    Logger.info "State when terminating #{inspect state}"

    case Websocket.close(connection) do
      :ok ->
        Logger.info "Connection closed"
      _error ->
        Logger.error "Unable to close connection"
    end
    :shutdown
  end

  def terminate(_, _) do
    :shutdown
  end
end
