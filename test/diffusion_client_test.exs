require Logger

defmodule Diffusion.Client.Test do
  alias Diffusion.Client
  alias Diffusion.Stub.Server
  alias Diffusion.Stub.WebsocketHandler

  use ExSpec, async: false

  setup_all do
    Code.load_file("test/diffusion_server_stub.ex")

    {:ok, _} = :application.ensure_all_started(:cowboy)

    {:ok, pid} = Server.start()

    [server_stub: pid]
  end

  test "connection" do
    {:ok, _} = Client.connect("127.0.0.1", 8080, "/diffusion_ws")

    assert Server.connection_established()
  end
end
