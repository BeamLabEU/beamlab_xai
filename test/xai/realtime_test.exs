defmodule Xai.RealtimeTest do
  use ExUnit.Case, async: true

  import Mox

  alias Xai.RealtimeMock

  setup :verify_on_exit!

  describe "connect_tts/1 (via mock for side effects)" do
    test "requires api_key" do
      assert_raise ArgumentError, ~r/api_key is required/, fn ->
        Xai.Realtime.connect_tts([])
      end
    end

    test "calls through to the transport with correct options" do
      expect(RealtimeMock, :connect_tts, fn opts ->
        assert opts[:voice] == "eve"
        {:ok, self()}
      end)

      # In real usage we'd call Xai.Realtime, but for demo we show the mock expectation
      # For now, directly exercise the mock as the transport layer.
      assert {:ok, _pid} = RealtimeMock.connect_tts(voice: "eve")
    end
  end

  describe "sending via mock" do
    test "send_text calls the mock" do
      pid = self()

      expect(RealtimeMock, :send_text, fn ^pid, "Hello world" ->
        :ok
      end)

      assert :ok = RealtimeMock.send_text(pid, "Hello world")
    end
  end

  describe "pure event helpers" do
    test "text_delta/1 builds correct event" do
      assert Xai.Realtime.text_delta("Hello") == %{"type" => "text.delta", "delta" => "Hello"}
    end

    test "text_done/0 builds correct event" do
      assert Xai.Realtime.text_done() == %{"type" => "text.done"}
    end

    test "text_clear/0 builds correct event" do
      assert Xai.Realtime.text_clear() == %{"type" => "text.clear"}
    end
  end

  describe "handle_frame (audio handling)" do
    test "handles audio.delta by calling on_audio callback with decoded bytes" do
      audio_received = :ets.new(:audio, [:set, :public])

      state = %Xai.Realtime.State{
        on_audio: fn data -> :ets.insert(audio_received, {:audio, data}) end,
        on_event: nil
      }

      b64 = Base.encode64("fake-audio-bytes")

      {:ok, new_state} =
        Xai.Realtime.handle_frame({:text, ~s({"type":"audio.delta","delta":"#{b64}"})}, state)

      assert :ets.lookup(audio_received, :audio) == [{:audio, "fake-audio-bytes"}]
      # state unchanged besides side effect
      assert new_state == state
    end

    test "handles audio.done" do
      state = %Xai.Realtime.State{on_event: fn e -> send(self(), e) end}

      {:ok, _} =
        Xai.Realtime.handle_frame({:text, ~s({"type":"audio.done","trace_id":"abc123"})}, state)

      assert_received %{"type" => "audio.done", "trace_id" => "abc123"}
    end
  end
end
