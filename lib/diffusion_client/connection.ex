require Logger

defmodule Diffusion.Connection do
  alias Diffusion.{Websocket, Router}

  use GenServer

  @name __MODULE__

  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number}

  defmodule State do
    @type t :: %State{connection: pid, mref: identifier}

    defstruct connection: nil, mref: nil

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


  @spec connect(pid, binary, number, binary, pos_integer, opts) :: {:ok, Diffusion.Session.t}
        when opts: [connection_conf]

  def connect(pid, host, port, path, timeout, opts) when is_pid(pid) do
    config = opts ++ [host: host, port: port, path: path, timeout: timeout]
    |> Enum.into(%{})

    GenServer.call(pid, {:connect, config})
  end


  @spec send(pid, String.t) :: :ok

  def send(pid, data) when is_binary(data) do
    GenServer.cast(pid, {:send, data})
  end


  # callbacks

  ##

  def init(opts) do
    # Process.flag(:trap_exit, true)
    Logger.info "session opts #{inspect opts}"

    {:ok, opts
    |> Enum.into(%{})
    |> Map.merge(State.new())}
  end

  ##

  def handle_info({'DOWN', mref, :process, _, reason}, %{mref: mref}) do
    {:stop, {:connection_down, reason}}
  end

  def handle_info({:gun_down, _, :ws, :closed, _, _}, _state) do
    {:stop, :websocket_down}
  end

  def handle_info({:gun_ws, _, {:text, data}}, state) do
    Logger.debug "Received -> #{data}"
    :ok = Router.route(data)
    {:noreply, state}
  end


  ##


  def handle_call({:connect, config}, _, state) do
    case Websocket.open_websocket(config) do
      {:ok, connection} ->
        new_state = %{mref: Process.monitor(connection), connection: connection}
        {:reply, {:ok, self()}, Map.merge(state, new_state)}
      error ->
        {:reply, error, state}
    end
  end


  ##

  def handle_cast({:send, data}, %{connection: connection} = state) when is_binary(data) do
    :ok = Websocket.send(connection, data)
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.info "Unexpected msg #{msg}"
    {:noreply, state}
  end

  def terminate(reason, %{connection: connection} = state) do
    Logger.error "Terminating, reason: #{reason} state #{state}"
    :ok = Websocket.close(connection)
    :shutdown
  end
end
