require Logger

defmodule Test do
  alias Diffusion.TopicHandler


  # temp test funs
  def test do
    {:ok, connection} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

    :ok = ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/B")
    :ok = ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/O")
    :ok = ExampleTopicHandler.new(connection, "Assets/FX/GBPUSD/B")
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
    Logger.info "#{inspect self()} ->  #{topic}: DELTA -> #{inspect delta}"
    {:ok, state}
  end
end
