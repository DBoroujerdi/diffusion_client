require Logger

defmodule Diffusion.Connection do
  alias Diffusion.{Websocket, Router}

  use GenServer

  # todo: the pid in connection should really be a via tuple
  @type t :: %{via: tuple, host: String.t, path: String.t}

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

    Diffusion.Supervisor.start_child(config)
  end


  def close(connection) do
    # todo: is this enough?
    send connection.via, :kill
  end

  # todo: rename this
  @spec send_data(tuple, String.t) :: :ok

  def send_data(via, data) when is_binary(data) do
    GenServer.cast(via, {:send, data})
  end


  # callbacks

  ##

  def init(opts) do
    # Process.flag(:trap_exit, true)
    Logger.info "session opts #{inspect opts}"

    send self(), :connect

    {:ok, opts}
  end

  ##

  def handle_info(:connect, %{owner: owner, host: host, path: path} = state) do
    case Websocket.open_websocket(state) do
      {:ok, connection} ->
        new_state = %{mref: Process.monitor(connection), connection: connection}
        send owner, {:connected, %{via: self(), host: host, path: path}}
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
    Logger.debug "Received -> #{data}"
    :ok = Router.route(data)
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
