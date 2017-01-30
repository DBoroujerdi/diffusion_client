require Logger

defmodule Test do
  alias Diffusion.Websocket.Protocol.DataMessage
  alias Diffusion.TopicHandler


  # temp test funs
  def test do
    {:ok, connection} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

    msg = %DataMessage{type: 21, headers: ["Commands", "0", "LOGON"], data: "pass\u{02}password"}
    :ok = Diffusion.Client.send(connection, msg)

    ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/B")
    # ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/O")
    # ExampleTopicHandler.new(connection, "Assets/FX/GBPUSD/B")

  end
end

defmodule ExampleTopicHandler do
  alias Diffusion.TopicHandler

  use TopicHandler

    # callbacks
  def topic_init(topic) do
    Logger.info "Topic init #{topic}"
    {:ok, %{}}
  end

  # todo: should print out pid here to explicitly show in the example that these are processed concurrently
  def topic_delta(topic, delta, state) do
    Logger.info "#{topic}: DELTA -> #{inspect delta}"
    {:ok, state}
  end
end
