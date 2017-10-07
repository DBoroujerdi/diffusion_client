require Logger

defmodule Test do
  alias Diffusion.TopicHandler


  # temp test funs
  def test do
    {:ok, session} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

    ExampleTopicHandler.start_link(session, "Assets/FX/EURUSD/B")
    ExampleTopicHandler.start_link(session, "Assets/FX/EURUSD/O")
    ExampleTopicHandler.start_link(session, "Assets/FX/GBPUSD/B")

    session
  end

  def wh do
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

    {:ok, session} = Diffusion.Client.connect("scoreboards-ssl.williamhill.com", 80, "/diffusion?v=4&ty=WB", 5000, [headers: headers, transport: :ssl])

    ExampleTopicHandler.start_link(session, "sportsbook/football/10703017/i18n/en-gb/commentary")

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

  def topic_delta(topic, delta, state) do
    Logger.info "#{inspect self()} ->  #{topic}: DELTA -> #{inspect delta}"
    {:ok, state}
  end
end
