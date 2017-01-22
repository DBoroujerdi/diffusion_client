defmodule Diffusion.Websocket.ProtocolTest do
  alias Diffusion.Websocket.Protocol
  alias Protocol.{ConnectionResponse, DataMessage}

  use ExSpec
  doctest Diffusion.Websocket.Protocol


  describe "decode" do

    context "valid binaries" do

      it "decodes connection respoonse" do
        expected = %ConnectionResponse{type: 100, client_id: "C8D4048FA5712A3A-006740E900000004", version: 4}
        actual = Protocol.decode("4\u{02}100\u{02}C8D4048FA5712A3A-006740E900000004")
        assert expected == actual
      end

      it "decodes topic load message" do
        expected = %DataMessage{type: 20, headers: ["Assets/FX/EURUSD!j4"], data: "0.4556"}
        actual = Protocol.decode("\u{14}Assets/FX/EURUSD!j4\u{01}0.4556")
        assert actual == expected
      end

      it "decodes topic load message with multiple data fields" do
        expected = %DataMessage{type: 20, headers: ["Assets/FX/EURUSD!j4"], data: "foo\u{01}bar\u{01}baz"}
        actual = Protocol.decode("\u{14}Assets/FX/EURUSD!j4\u{01}foo\u{01}bar\u{01}baz")
        assert actual == expected
      end

      it "decodes delta message" do
        expected = %DataMessage{type: 21, headers: ["!je"], data: "1.6752"}
        actual = Protocol.decode("\u{15}!je\u{01}1.6752")
        assert actual == expected
      end

      it "decodes client ping message" do
        bin = "\u{19}1484349590272\u{01}"
        assert Protocol.decode(bin) == %DataMessage{type: 25, headers: ["1484349590272"], data: ""}
      end
    end

    context "invalid inputs" do

      it "returns error for empty binary" do
        assert Protocol.decode(<<>>) == {:error, :empty_binary}
      end

      it "should throw error for non binary" do
        catch_error Protocol.decode(42)
      end
    end
  end


  describe "encoding" do

    it "encodes client ping" do
      expected = "\u{19}1484349590272\u{01}"
      actual = Protocol.encode(%DataMessage{type: 25, headers: ["1484349590272"], data: ""})
      assert actual == expected
    end

    it "encodes data message" do
      data = %DataMessage{type: 20, headers: ["sportsbook/football/9935205/stats/score!o638"], data: "0 - 0"}
      actual =  Protocol.encode(data)
      expected = "\u{14}sportsbook/football/9935205/stats/score!o638\u{01}0 - 0"
      assert actual == expected
    end

    it "encodes logon command" do
      data = %DataMessage{type: 21, headers: ["Commands", "0", "LOGON"], data: "pass\u{02}password"}
      actual = Protocol.encode(data)
      expected = "\u{15}Commands\u{02}0\u{02}LOGON\u{01}pass\u{02}password"
      assert actual == expected
    end

    it "encodes connection response" do
      data = %ConnectionResponse{type: 100, client_id: "C8D4048FA5712A3A-006740E900000004", version: 4}
      actual = Protocol.encode(data)
      expected = "4\u{02}100\u{02}C8D4048FA5712A3A-006740E900000004"
      assert actual == expected
    end
  end
end
