require Logger

defmodule Test do

  alias Diffusion.Websocket.Protocol.DataMessage, as: DataMessage

  # temp test funs
  def test do
    {:ok, session} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

    msg = %DataMessage{type: 21, headers: ["Commands", "0", "LOGON"], data: "pass\u{02}password"}
    :ok = Diffusion.Client.send(session, msg)

    Diffusion.Client.add_topic(session, "Assets/FX/EURUSD/B", __MODULE__)
    Diffusion.Client.add_topic(session, "Assets/FX/EURUSD/O", __MODULE__)
    Diffusion.Client.add_topic(session, "Assets/FX/GBPUSD/B", __MODULE__)

  end

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

    Diffusion.Client.add_topic(session, "sportsbook/football/10524850/i18n/en-gb/commentary", __MODULE__)
    Diffusion.Client.add_topic(session, "sportsbook/football/10524850/stats/time", __MODULE__)

    session
  end


  def handle(msg) do
    Logger.info "DELTA -> #{inspect msg}"
  end


end
