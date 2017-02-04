# DiffusionClient

An OTP application for consuming data from [Diffusion](https://www.pushtechnology.com/products/diffusion) topics over Websocket.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `diffusion_client` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:diffusion_client, "~> 0.1.0"}]
    end
    ```

  2. Ensure `diffusion_client` is started before your application:

    ```elixir
    def application do
      [applications: [:diffusion_client]]
    end
    ```

## Examples

``` elixir
iex> defmodule ExampleTopicHandler do
  alias Diffusion.TopicHandler

  use TopicHandler

  # callbacks
  def topic_init(topic) do
    Logger.info "Topic init #{topic}"
    {:ok, %{}}
  end

  def topic_delta(topic, delta, state) do
    Logger.info "#{topic}: DELTA -> #{inspect delta}"
    {:ok, state}
  end
end

iex> {:ok, connection} = Diffusion.Client.connect("demo.pushtechnology.com", 80, "/diffusion?t=Commands&v=4&ty=WB", 5000, [])

iex> ExampleTopicHandler.start_link(connection, "Assets/FX/EURUSD/B")
iex> ExampleTopicHandler.start_link(connection, "Assets/FX/EURUSD/O")

...
21:35:07.539 [info]  Topic init Assets/FX/EURUSD/O

21:35:07.539 [info]  Topic init Assets/FX/GBPUSD/B

21:35:09.255 [info]  #PID<0.166.0> ->  Assets/FX/GBPUSD/B: DELTA -> %Diffusion.Websocket.Protocol.Delta{data: "1.6709", topic_alias: "!je", type: 21}

21:35:07.865 [info]  #PID<0.165.0> ->  Assets/FX/EURUSD/O: DELTA -> %Diffusion.Websocket.Protocol.Delta{data: "1.4541", topic_alias: "!j5", type: 21}

21:35:09.997 [info]  #PID<0.166.0> ->  Assets/FX/GBPUSD/B: DELTA -> %Diffusion.Websocket.Protocol.Delta{data: "1.6707", topic_alias: "!je", type: 21}

21:35:11.067 [info]  #PID<0.165.0> ->  Assets/FX/EURUSD/O: DELTA -> %Diffusion.Websocket.Protocol.Delta{data: "1.4539", topic_alias: "!j5", type: 21}
```


## TODO

- Implement delta handler as a GenStage stream
- Proper testing
