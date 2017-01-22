require Logger

defmodule Diffusion.Client do
  use Application

  alias Diffusion.Session
  alias Diffusion.Supervisor

  alias Diffusion.Websocket.Protocol.DataMessage, as: DataMessage


  # API functions

  @doc """
  Connect to diffusion server at host:port/path. Initiates connection and returns
  a session struct representing the session. This session should be used
  in all interactions with the client.
  """

  @spec connect(String.t, number, opts) :: {:ok, Session.t} when opts: [atom: any]

  def connect(host, port \\ 80, path, timeout \\ 5000, opts \\ []) do
    Logger.info "connecting..."

    with {:ok, pid} <- Supervisor.start_child(opts),
         :valid <- validate_opts(opts)
      do Session.connect(pid, host, port, path, timeout, opts)
      else
        error -> error
    end
  end


  @doc """
  Subscribe to data stream for a command on a session.

  todo: command should be a proper data type here.
  todo: should return an erro case if subscription was not possible for some
  reason. maybe the topic doesn't exist
  """

  # todo: can a module call be typed??

  @spec add_topic(Session.t, binary, module) :: :ok | {:error, any}

  def add_topic(session, topic, callback) do
    Logger.info "Adding topic to #{inspect topic} with callback #{inspect callback}"

    if Process.alive?(session.pid) do
      Session.add_topic(session, topic, callback)
    else
      {:error, :no_local_process_found}
    end
  end


  @spec send(Session.t, DataMessage.t) :: :ok

  def send(session, data) do
    if Process.alive?(session.pid) do
      Session.send(session, data)
    else
      {:error, :no_local_process_found}
    end
  end


  @doc """
  Unsubscribe from subscribed stream.

  todo: returns error is unsub failed
  """

  @spec close_session(Session.t) :: :ok | {:error, any}

  def close_session(session) do
    if Process.alive?(session.pid) do
      Supervisor.stop_child(session)
    else
      {:error, :no_local_process_found}
    end
  end


  @spec start() :: {:ok, [atom]} | {:error, {atom, term}}

  def start() do
    Application.ensure_all_started(__MODULE__)
  end


  def start(_, _) do
    Logger.info "Starting DiffusionClient"

    Diffusion.Supervisor.start_link()
  end

  ##
  ## Private
  ##

  defp validate_opts(_opts) do
    # todo:
    :valid
  end

end
