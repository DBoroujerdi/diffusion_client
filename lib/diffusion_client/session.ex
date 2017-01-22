require Logger

defmodule Diffusion.Session do
  alias Diffusion.{Handler, Session, Websocket, TopicMappings}
  alias Session.State
  alias Websocket.Protocol
  alias Protocol.DataMessage

  use GenServer

  @name __MODULE__

  defstruct id: nil, pid: nil, topics: []

  @type t :: %Session{id: String.t, pid: pid, topics: list}

  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t} | {:timeout, number}

  defmodule State do
    @type t :: %State{id: String.t,
                      session: Session.t,
                      connection: pid,
                      mref: identifier,
                      topic_mappings: TopicMappings.t}

    defstruct id: nil, session: nil, session: nil,
              connection: nil, mref: nil, topic_mappings: TopicMappings.new

    def new do
      %State{}
    end

    def update_mappings(state, mappings) do
      Map.put(state, :topic_mappings, mappings)
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


  @spec add_topic(Session.t, binary, module, number) :: :ok

  def add_topic(session, topic, callback, timeout \\ 5000) do
    GenServer.cast(session.pid, {:add_topic, topic, callback})

    receive do
      {:topic_loaded, ^topic} -> :ok
      error -> error
    after timeout
      -> {:error, :timeout}
    end
  end


  @spec send(Session.t, DataMessage.t) :: :ok

  def send(session, data) do
    GenServer.cast(session.pid, {:send, data})
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

  def handle_info({:gun_ws, _, {:text, data}}, %{session: session} = state) do
    Logger.debug "Received -> #{data}"

    state = Handler.handle_msg(session, data, state)

    {:noreply, state}
  end


  ##


  def handle_call({:connect, config}, _, %{id: id} = state) do
    case Websocket.open_websocket(config) do
      {:ok, connection} ->
        new_session = %Session{id: id, pid: self()}
        new_state = %{mref: Process.monitor(connection), connection: connection, session: new_session}
        {:reply, {:ok, new_session}, Map.merge(state, new_state)}
      error ->
        {:reply, error, state}
    end
  end


  ##

  def handle_cast({:add_topic, topic, handler}, %{connection: connection} = state) do
    updated_mappings = TopicMappings.add_topic(state.topic_mappings, topic, handler)

    data = Protocol.encode(%DataMessage{type: 22, headers: [topic]})
    :ok = Websocket.send(connection, data)

    {:noreply, State.update_mappings(state, updated_mappings)}
  end

  def handle_cast({:send, %DataMessage{} = data}, %{connection: connection} = state) when is_map(data) do
    :ok = Websocket.send(connection, Protocol.encode(data))
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
