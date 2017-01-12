require Logger
require Monad.Error, as: Error

import Error

defmodule Diffusion.Session do
  use GenServer

  @name __MODULE__

  defstruct [:pid]
  # todo: expand this struct with additional useful session information
  @type t :: %__MODULE__{pid: pid}
  @type connection_conf :: {:host, String.t} | {:port, number} | {:path, String.t}


  # API

  @spec start_link(opts) :: GenServer.on_start when opts: [{:id, String.t}]

  def start_link(opts) do
    Logger.info "#{inspect opts}"
    GenServer.start_link(@name, opts, [])
  end


  @spec connect(pid, number, config) :: {:ok, Diffusion.Session.t} when config: [connection_conf]

  def connect(pid, _timeout, config) when is_pid(pid) do
    # todo: should the timeout value be passed into
    # the process then to gun somehow?
    GenServer.call(pid, {:connect, config |> Enum.into(%{})})

    # receive do
    #   session -> session
    # after timeout ->
    #     Error.fail("timed out establishing websocket")
    # end
  end


  @spec send(pid, binary) :: :ok

  def send(pid, data) do
    GenServer.cast(pid, {:send, data})
  end


  @spec get_session_id(pid) :: binary

  def get_session_id(pid) do
    GenServer.call(pid, :get_id)
  end

  # callbacks

  ##

  def init(opts) do
    # Process.flag(:trap_exit, true)
    Logger.info "session opts #{inspect opts}"
    {:ok, opts |> Enum.into(%{})}
  end

  ##



  def handle_info({'DOWN', mref, :process, _, reason}, %{mref: mref}) do
    {:stop, {:connection_down, reason}}
  end

  def handle_info({:gun_ws, _pid, {:text, data}}, %{connection: connection} = state) do
    Logger.info "Received -> #{data}"

    case is_timestamp(data) do
      true ->
        # ping back
        :ok = :gun.ws_send(connection, {:text, data})
      false ->
        # todo: pass message to call back of send to owner process
    end

    {:noreply, state}
  end


  def handle_call({:connect, config}, _, state) do
    case open_websocket(config) do
      {:ok, connection} ->
        new_state = %{mref: Process.monitor(connection), connection: connection}
        {:reply, {:ok, %Diffusion.Session{pid: self()}}, Map.merge(new_state, state)}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get_id, _, %{id: id} = state) do
    {:reply, id, state}
  end

  ##

  def handle_cast({:send, command}, %{connection: connection} = state) do
    :ok = :gun.ws_send(connection, {:binary, command})
    {:noreply, state}
  end

  def handle_cast({:push, item}, state) do
    {:noreply, [item | state]}
  end


  ## private functions

  defp open_websocket(config) do
    case open_connection(config) do
      {:ok, connection} = ok ->
        case wait_up(ok, config) do
          {:ok, _} -> ok
          error ->
            # close connection if anything goes wrong
            # whilst waiting for the connection to ws
            # to establish
            _ = :gun.close(connection)
            error
        end
    end
  end


  defp wait_up(connection, config) do
    Error.p do
      connection
      |> await_up()
      |> upgrade_to_ws(config)
    end
  end


  defp upgrade_to_ws(connection, %{path: path}) do
    _ = :gun.ws_upgrade(connection, path)

    receive do
      {:gun_ws_upgrade, ^connection, :ok, _} ->
        {:ok, connection}
      other ->
        {:error, {:unexpected_message, other}}
    end
  end

  defp open_connection(%{host: host, port: port}) do
    :gun.open(String.to_charlist(host), port)
  end


  defp await_up(connection) do
    case :gun.await_up(connection) do
      {:ok, _} -> {:ok, connection}
      error -> error
    end
  end


  # todo: move this function to protocols lib
  defp is_timestamp(<<25, _::binary>>), do: true
  defp is_timestamp(_) do
    false
  end

  # implement on terminate so we can close the gun process gracefully
end
