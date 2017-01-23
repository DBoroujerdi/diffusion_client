require Logger

defmodule Diffusion.Connection do
  alias Diffusion.{Websocket, Router, ConnectionSup}

  use GenServer

  @name __MODULE__

  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number} | {:owner, pid}

  defmodule State do
    @type t :: %State{connection: pid, mref: identifier, owner: pid}

    defstruct connection: nil, mref: nil, owner: nil

    def new do
      %State{}
    end
  end

  # API

  @spec start_link(opts) :: GenServer.on_start when opts: [{:id, String.t}]

  def start_link(opts) do
    Logger.info "#{inspect opts}"
    GenServer.start_link(@name, opts, [])
  end


  @spec new(binary, number, binary, pos_integer, opts) :: Supervisor.on_start_child
        when opts: [{atom, any}]

  def new(host, port, path, timeout, opts) do
    config = opts ++ [host: host, port: port, path: path, timeout: timeout, owner: self()]
    |> Enum.into(%{})

    ConnectionSup.start_child(config)
  end


  def close(connection) when is_pid(connection) do
    # todo: is this enough?
    send connection, :kill
  end

  # todo: rename this
  @spec send_data(pid, String.t) :: :ok

  def send_data(pid, data) when is_binary(data) do
    GenServer.cast(pid, {:send, data})
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

  def handle_info(:connect, %{owner: owner} = state) do
    case Websocket.open_websocket(state) do
      {:ok, connection} ->
        new_state = %{mref: Process.monitor(connection), connection: connection}
        send owner, :connected
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
      error ->
        Logger.error "Unable to close connection"
    end
    :shutdown
  end

  def terminate(_, _) do
    :shutdown
  end
end
