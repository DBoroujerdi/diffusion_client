require Logger

defmodule Diffusion.Session do
  alias Diffusion.Session

  @type t :: %Session{aka: tuple, host: String.t, path: String.t}

  # todo: rename aka to connection_pid
  defstruct [:aka, :host, :host, :path]


  @spec new(binary, number, binary, pos_integer, opts) :: {:ok, Session.t} | {:error, any}
        when opts: [{atom, any}]

  def new(host, port, path, timeout, opts) do
    config = opts ++ [host: host, port: port, path: path, timeout: timeout, owner: self()]
    |> Enum.into(%{})

    case Diffusion.Supervisor.start_socket_connection(config) do
      {:ok, pid} ->
        receive do
          {:started, connection} ->
            {:ok, %Session{aka: connection, host: host, path: path}}
          error ->
            Diffusion.Supervisor.stop_child(pid)
            error
        after timeout
            -> {:error, :timeout}
        end
      error -> error
    end
  end


  @spec alive?(Session.t) :: boolean

  def alive?(connection) do
    pid = :gproc.lookup_pid(connection.aka)
    Process.alive?(pid)
  end


  @spec close(Session.t) :: :ok | {:error, any}

  def close(connection) do
    Diffusion.Supervisor.stop_child(connection)
  end


  @spec send_data(identifier, String.t) :: :ok when identifier: tuple | pid

  def send_data(pid, data) when is_binary(data) do
    GenServer.cast(pid, {:send, data})
  end
end
