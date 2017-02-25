defmodule Diffusion.Websocket.Protocol do

  # http://docs.pushtechnology.com/docs/5.1.18/manual/com.pushtechnology.diffusion.manual_5.1.18/protocol/r_messages-protocol.html


  @type message :: ConnectionResponse.t | Delta.t | TopicLoad.t | Ping.t | map

  defmodule ConnectionResponse do
    @type t :: connection_response

    @type connection_type     :: 100 | 105
    @type connection_response :: %ConnectionResponse{type: connection_type, client_id: String.t, version: number}

    defstruct [:type, :client_id, :version]
  end

  defmodule Delta do
    @type t :: delta

    @type delta :: %Delta{type: 21, data: String.t, topic_alias: String.t, headers: [String.t]}

    defstruct [:type, :data, :topic_alias, headers: []]
  end

  defmodule TopicLoad do
    @type t :: topic_load

    @type topic_load :: %TopicLoad{type: 20, topic: String.t, topic_alias: String.t}

    defstruct [:type, :data, :topic, :topic_alias]
  end

  defmodule Ping do
    @type t :: ping

    @type ping :: %Ping{type: 25, timestamp: String.t}

    defstruct [:type, :timestamp]
  end

  defmodule Message do
    @type t :: data_message

    @type data         :: binary
    @type header       :: binary
    @type message_type :: 20..48
    @type data_message ::  %Message{type: message_type, headers: [header], data: data}

    defstruct [:type, headers: [], data: <<>>]
  end




  @type connection_type     :: 100 | 105
  @type connection_response :: %ConnectionResponse{type: connection_type, client_id: String.t, version: number}

  @type reason :: any()


  @doc """
  Decode a message binary in the form - TH...D...
  Where T is the message-type byte, H is optional header bytes seperated
  by field delimiters FD and D is the data bytes also seperated by field
  delimiters.

  ## Examples

      %Delta{type: 21, topic_alias: "!je", data: "1.6752"} = Protocol.decode("\u{15}!je\u{01}1.6752")
      %Ping{type: 25, timestamp: "1484349590272"} = Protocol.decode("\u{19}1484349590272\u{01}")

  """

  @spec decode(binary) :: message | {:error, reason}
  def decode(bin) do
    try do
      do_decode(bin)
    catch
      _, value ->
        {:error, value}
    end
  end


  defp do_decode(<<>>), do: {:error, :empty_binary}

  defp do_decode(<<type::integer, rest::binary>>) when type >= 20 and type <= 48 do
    decode_message(type, :binary.split(rest, "\u{01}"))
  end

  defp do_decode(bin) when is_binary(bin) do
    <<
      version_bin  :: bytes-size(1), "\u{02}",
      type_bin     :: bytes-size(3), "\u{02}",
      client_id    :: binary
    >> = bin

    with {version, ""} <- Integer.parse(version_bin),
         {type, ""}    <- Integer.parse(type_bin)
      do %ConnectionResponse{type: type, client_id: client_id, version: version}
      else
        _ -> {:error, :decode_failure}
    end
  end


  defp decode_message(20 = type, [headers, data]) do
    case :binary.split(headers, "!") do
      [left, right] ->
        %TopicLoad{type: type, data: data, topic: left, topic_alias: "!" <> right}
    end
  end

  defp decode_message(21 = type, [headers, data]) do
    case :binary.split(headers, "\u{02}", [:global]) do
      [topic_alias] ->
        %Delta{type: type, data: data, topic_alias: topic_alias}
      [topic_alias | headers] ->
        %Delta{type: type, data: data, topic_alias: topic_alias, headers: headers}
    end
  end

  defp decode_message(25 = type, [data, _]) do
    %Ping{type: type, timestamp: data}
  end

  defp decode_message(type, [data]) do
    %Message{type: type, data: split(data), headers: []}
  end

  defp decode_message(type, [headers, data]) do
    %Message{type: type, data: data, headers: split(headers)}
  end



  @doc """
  Encode a diffusion message as a binary of the form TH...D...
  Where T is the message-type byte, H is optional header bytes seperated
  by field delimiters FD and D is the data bytes also seperated by field
  delimiters.

  ## Example

      "\u{19}1484349590272\u{01}" = Protocol.encode(%Ping{type: 25, timestamp: "1484349590272"})

  """

  @spec encode(message) :: String.t
  def encode(data) do
    try do
      do_encode(data)
    catch
      _, value ->
        {:error, value}
    end
  end


  defp do_encode(%ConnectionResponse{type: type, client_id: id, version: version}) do
    Integer.to_string(version) <> "\u{02}" <> Integer.to_string(type) <> "\u{02}" <> id
  end

  defp do_encode(%Ping{type: type, timestamp: timestamp}) do
    type_of(type) <> timestamp <> "\u{01}"
  end

  defp do_encode(%{type: type, data: data, headers: headers}) do
    type_of(type) <> Enum.join(headers, "\u{02}") <> "\u{01}" <> data
  end


  defp type_of(type) do
    case type do
      20 -> "\u{14}" # Topic load message
      21 -> "\u{15}" # Delta message
      22 -> "\u{16}" # Subscribe/Register
      23 -> "\u{17}" # Unsubscribe/Unregister
      24 -> "\u{18}" # Ping server
      25 -> "\u{19}" # Ping client
      26 -> "\u{1A}" # Credentials
      27 -> "\u{1B}" # Credentials rejected
      28 -> "\u{1C}" # Abort notification
      29 -> "\u{1D}" # Close request
      30 -> "\u{1E}" # Topic load - ACK Required
      31 -> "\u{1F}" # Delta - ACK Required
      32 -> "\u{20}" # ACK - acknowledge
      33 -> "\u{21}" # Fetch topic
      34 -> "\u{22}" # Fetch reply
      35 -> "\u{23}" # Topic status notification
      36 -> "\u{24}" # Command message topic
      40 -> "\u{28}" # Command topic load
      41 -> "\u{29}" # Command topic notification
      48 -> "\u{30}" # Cancel fragmented message set
    end
  end

  defp split(bin) do
    String.split(bin, "\u{02}")
  end

end
