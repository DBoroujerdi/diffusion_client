require Logger

defmodule Diffusion.Connection do
  alias Diffusion.{Connection, TopicHandler, Websocket}
  alias Diffusion.Websocket.Protocol
  alias Protocol.Ping

  @type t :: %Connection{aka: tuple, host: String.t, path: String.t}

  defstruct [:aka, :host, :host, :path]


  @spec new(binary, number, binary, pos_integer, opts) :: {:ok, Connection.t} | {:error, any}
        when opts: [{atom, any}]

  def new(host, port, path, timeout, opts) do
    config = opts ++ [host: host, port: port, path: path, timeout: timeout, owner: self()]
    |> Enum.into(%{})

    case Diffusion.Supervisor.start_socket_consumer(config) do
      {:ok, pid} ->
        receive do
          {:started, consumer_via} ->
            {:ok, %Connection{aka: consumer_via, host: host, path: path}}
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


  @spec close(Connection.t) :: :ok | {:error, any}

  def close(connection) do
    Diffusion.Supervisor.stop_child(connection)
  end


  @spec send_data(identifier, String.t) :: :ok when identifier: tuple | pid

  def send_data({:n, :l, _} = key, data) when is_binary(data) do
    GenServer.cast({:via, :gproc, key}, {:send, data})
  end
end
