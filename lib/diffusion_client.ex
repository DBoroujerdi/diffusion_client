require Logger

defmodule Diffusion.Client do
  use Application


  # temp test funs
  def test() do
    connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])
  end


  # API functions

  @type session :: Diffusion.Session.t

  # todo: api additions
  # - request/response model


  @doc """
  todo
  """

  @spec connect(String.t, number, opts) :: {:ok, session} when opts: [client_type: atom]

  def connect(host, port \\ 80, path, timeout \\ 5000, opts \\ []) do
    Logger.info "connecting..."
    # todo: option validation?
    case Diffusion.SessionSupervisor.start_child(opts) do
      {:ok, pid} ->
        Diffusion.Session.connect(pid, host: host, port: port, path: path, timeout: timeout)
      error -> error
    end
  end


  @doc """
  todo
  """

  @spec send(session, args) :: :ok when args: list

  def send(%Diffusion.Session{pid: pid}, args) do
    Kernel.send pid, args
  end


  @spec start() :: {:ok, [atom]} | {:error, {atom, term}}

  def start() do
    Application.ensure_all_started(__MODULE__)
  end


  def start(_, _) do
    Logger.info "Starting DiffusionClient"

    # msg = <<15,"topicName", 2, "topicAlias", 1, "Data1", 2, "Data2">>
    #
    # :diffusion_messages.decode(msg)
    Diffusion.SessionSupervisor.start_link()
  end
end
