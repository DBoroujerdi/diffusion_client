defmodule Diffusion.Websocket.Protocol do

  # http://docs.pushtechnology.com/docs/5.1.18/manual/com.pushtechnology.diffusion.manual_5.1.18/protocol/r_messages-protocol.html

  # todo: headers on the decoded result should work like headers.topic, headers.alias
  # - would require a per type parsing of the binary which would make this module a lot more complicated.
  # currently, calling client have to know about the index of a particular header which isn't ideal.

  defmodule ConnectionResponse do
    @type t :: connection_response

    @type connection_type     :: 100 | 105
    @type connection_response :: %ConnectionResponse{type: connection_type, client_id: String.t, version: number}

    defstruct [:type, :client_id, :version]
  end

  defmodule DataMessage do
    @type t :: data_message

    @type data         :: binary
    @type header       :: binary
    @type message_type :: 20..48
    @type data_message ::  %DataMessage{type: message_type, headers: [header], data: data}

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

  ## Example

      %DataMessage{type: 21, headers: ["!je"], data: "1.6752"} = Protocol.decode("\u{15}!je\u{01}1.6752")

  """

  @spec decode(binary) :: DataMessage.t | ConnectionResponse.t | {:error, reason}
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
    case :binary.split(rest, "\u{01}") do
      [data] ->
        %DataMessage{type: type, data: split(data), headers: []}
      [headers, data] ->
        %DataMessage{type: type, data: data, headers: split(headers)}
      _ ->
        {:error, :decode_failure}
    end
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


  @doc """
  Encode a diffusion message as a binary of the form TH...D...
  Where T is the message-type byte, H is optional header bytes seperated
  by field delimiters FD and D is the data bytes also seperated by field
  delimiters.

  ## Example

      "\u{19}1484349590272\u{01}" = Protocol.encode(%DataMessage{type: 25, headers: ["1484349590272"], data: ""})

  """

  @spec encode(DataMessage.t) :: String.t
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

  defp do_encode(%DataMessage{type: type, data: data, headers: headers}) do
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
