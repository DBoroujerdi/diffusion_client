# DiffusionClient

A tool for consuming data from [Diffusion](https://www.pushtechnology.com/products/diffusio) topics over Websockets.


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
iex> msg = %DataMessage{type: 21, headers: ["Commands", "0", "LOGON"], data: "pass\u{02}password"}
iex> :ok = Diffusion.Client.send(connection, msg)
iex> :ok = ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/B")
iex> :ok = ExampleTopicHandler.new(connection, "Assets/FX/EURUSD/O")

...

00:50:13.427 [info]  Assets/FX/EURUSD/B: DELTA -> %Diffusion.Websocket.Protocol.DataMessage{data: "1.4528", headers: ["!j4"], type: 21}

00:50:13.427 [info]  Assets/FX/EURUSD/O: DELTA -> %Diffusion.Websocket.Protocol.DataMessage{data: "1.4530", headers: ["!j5"], type: 21}
```
