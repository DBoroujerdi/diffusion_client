require Logger

defmodule Test do
  alias Diffusion.Websocket.Protocol.DataMessage
  alias Diffusion.TopicHandler


  # temp test funs
  def test do
    {:ok, session} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

    msg = %DataMessage{type: 21, headers: ["Commands", "0", "LOGON"], data: "pass\u{02}password"}
    :ok = Diffusion.Client.send(session, msg)

    ExampleTopicHandler.new(session, "Assets/FX/EURUSD/B")
    ExampleTopicHandler.new(session, "Assets/FX/EURUSD/O")
    ExampleTopicHandler.new(session, "Assets/FX/GBPUSD/B")

  end

  # todo: remove this example - should be moved to a william hill specific app
  def test2() do
    headers = [
      {"Pragma", "no-cache"},
      ##
      {"Cache-Control", "no-cache"},
      ##
      {"Origin", "http://scoreboards.williamhill.com"},
      ##
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36"},
      ##
      {"Accept-Encoding", "gzip, deflate, sdch"},
      ##
      {"Accept-Language", "en-GB,en-US;q=0.8,en;q=0.6"},
      ##
      {"Sec-WebSocket-Extensions", "permessage-deflate; client_max_window_bits"}
    ]

    {:ok, session} = Diffusion.Client.connect("scoreboards.williamhill.com", 80, "/diffusion?t=sportsbook%2Ffootball%2Fstatus&v=4&ty=WB", 5000, [headers: headers])

    ExampleTopicHandler.new(session, "sportsbook/football/10476395/i18n/en-gb/commentary")
    # ExampleTopicHandler.new(session, "sportsbook/football/10476395/stats/time")

    session
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
