require Logger

defmodule Diffusion.Client do
  use Application

  alias Diffusion.Session
  alias Diffusion.Websocket.Protocol
  alias Protocol.DataMessage


  # API functions

  @doc """
  Connect to diffusion server at host:port/path. Initiates session and returns
  a session struct representing the session. This session should be used
  in all interactions with the client.
  """

  @spec connect(String.t, number, String.t, number, opts) :: {:ok, Session.t} | {:error, any} when opts: [atom: any]

  def connect(host, port \\ 80, path, timeout \\ 5000, opts \\ []) do
    Logger.info "connecting..."

    case validate_opts(opts) do
      :valid ->
        Session.new(host, port, path, timeout, opts)
      error ->
        error
    end
  end


  @spec send(Session.t, DataMessage.t) :: :ok | {:error, :session_down}

  def send(session, data) do
    Session.send_data(session.aka, Protocol.encode(data))
  end


  @doc """
  Close a session. All topic subscriptions consuming from the session
  will also close as a result.
  """

  @spec close_session(Session.t) :: :ok | {:error, any}

  def close_session(session) do
    Session.close(session)
  end


  @spec start() :: {:ok, [atom]} | {:error, {atom, term}}

  def start() do
    Application.ensure_all_started(__MODULE__)
  end


  def start(_, _) do
    import Supervisor.Spec

    Logger.info "Starting DiffusionClient"

    # todo: support starting session and subscriptions
    # from config

    children = [
      supervisor(Diffusion.Connections.Supervisor, []),
      supervisor(Registry, [:unique, Diffusion.Registry])
    ]

    opts = [strategy: :one_for_one, name: Diffusion.Supervisor]
    Supervisor.start_link(children, opts)
  end

  ##
  ## Private
  ##

  defp validate_opts(_opts) do
    # todo: implement validation
    :valid
  end

end
