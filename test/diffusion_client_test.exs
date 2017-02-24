require Logger

defmodule Diffusion.Client.Test do
  alias Diffusion.Client

  use ExSpec, async: false

  setup_all do
    Code.load_file("test/diffusion_server_stub.ex")

    {:ok, _} = :application.ensure_all_started(:cowboy)

    {:ok, pid} = Diffusion.ServerStub.start()

    [server_stub: pid]
  end

  test "connection", context do
    {:ok, session} = Client.connect("127.0.0.1", 8080, "/diffusion_ws")

    assert Diffusion.ServerStub.connection_established()
  end
end
