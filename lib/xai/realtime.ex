defmodule Xai.Realtime do
  @moduledoc """
  WebSocket client for xAI realtime voice and streaming TTS.

  xAI exposes realtime features over WebSocket (not gRPC):
  - `wss://api.x.ai/v1/realtime` for full voice agents (bidirectional audio + text)
  - `wss://api.x.ai/v1/tts` for bidirectional streaming TTS

  This module uses Websockex. It is separate from the gRPC `Xai.Client`
  because the transports are different.

  ## Example: Streaming TTS

      {:ok, pid} = Xai.Realtime.connect_tts(
        api_key: System.get_env("XAI_API_KEY"),
        voice: "eve",
        codec: "mp3",
        on_audio: fn audio_chunk -> play_audio(audio_chunk) end
      )

      Xai.Realtime.send_text(pid, "Hello from Elixir. ")
      Xai.Realtime.send_text(pid, "This is streaming TTS.")
      Xai.Realtime.send_text_done(pid)

  For full realtime voice agents, use `connect_realtime/1` and handle events.
  """

  use WebSockex

  @behaviour Xai.RealtimeBehaviour

  @type t :: pid()
  @type on_audio :: (binary() -> any())
  @type on_event :: (map() -> any())

  @tts_url "wss://api.x.ai/v1/tts"
  @realtime_url "wss://api.x.ai/v1/realtime"

  @max_reconnect_attempts 5
  @reconnect_base_backoff_ms 500
  @reconnect_max_backoff_ms 30_000

  defmodule State do
    @moduledoc false
    defstruct [
      :api_key,
      :on_audio,
      :on_event,
      :url,
      buffer: <<>>
    ]
  end

  @doc """
  Connect for streaming TTS (text → audio chunks).

  Options:
    - `:api_key` (required, or XAI_API_KEY env)
    - `:voice` - default "eve"
    - `:language` - default "en"
    - `:codec` - mp3, wav, pcm, etc.
    - `:sample_rate`
    - `:on_audio` - callback for base64-decoded audio chunks
    - `:on_event` - callback for all JSON events (optional)
  """
  @impl Xai.RealtimeBehaviour
  @spec connect_tts(keyword()) :: {:ok, t()} | {:error, term()}
  def connect_tts(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("XAI_API_KEY")
    unless api_key, do: raise(ArgumentError, "api_key is required")

    voice = Keyword.get(opts, :voice, "eve")
    language = Keyword.get(opts, :language, "en")
    codec = Keyword.get(opts, :codec, "mp3")
    sample_rate = Keyword.get(opts, :sample_rate, 24_000)

    query =
      URI.encode_query(
        language: language,
        voice: voice,
        codec: codec,
        sample_rate: sample_rate
      )

    url = "#{@tts_url}?#{query}"

    state = %State{
      api_key: api_key,
      on_audio: Keyword.get(opts, :on_audio),
      on_event: Keyword.get(opts, :on_event),
      url: url
    }

    extra_headers = [{"Authorization", "Bearer #{api_key}"}]

    WebSockex.start_link(url, __MODULE__, state, extra_headers: extra_headers)
  end

  @doc """
  Connect to the full realtime voice agent endpoint.

  Similar options, plus session configuration sent after connect.
  """
  @impl Xai.RealtimeBehaviour
  @spec connect_realtime(keyword()) :: {:ok, t()} | {:error, term()}
  def connect_realtime(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("XAI_API_KEY")
    model = Keyword.get(opts, :model, "grok-voice-latest")

    url = "#{@realtime_url}?model=#{model}"

    state = %State{
      api_key: api_key,
      on_event: Keyword.get(opts, :on_event),
      url: url
    }

    extra_headers = [{"Authorization", "Bearer #{api_key}"}]

    WebSockex.start_link(url, __MODULE__, state, extra_headers: extra_headers)
  end

  @impl Xai.RealtimeBehaviour
  @doc "Send a text delta for TTS or conversation."
  def send_text(pid, text) do
    msg = %{"type" => "text.delta", "delta" => text}
    WebSockex.send_frame(pid, {:text, JSON.encode!(msg)})
  end

  @impl Xai.RealtimeBehaviour
  @doc "Signal end of text for current utterance (TTS)."
  def send_text_done(pid) do
    WebSockex.send_frame(pid, {:text, JSON.encode!(%{"type" => "text.done"})})
  end

  @impl Xai.RealtimeBehaviour
  @doc "Send raw event (for advanced realtime use)."
  def send_event(pid, event) when is_map(event) do
    WebSockex.send_frame(pid, {:text, JSON.encode!(event)})
  end

  @impl Xai.RealtimeBehaviour
  @doc "Close the connection gracefully."
  def close(pid) do
    WebSockex.cast(pid, :close)
  end

  # WebSockex callbacks

  @impl true
  def handle_frame({:text, msg}, state) do
    case JSON.decode(msg) do
      {:ok, event} -> handle_event(event, state)
      _ -> {:ok, state}
    end
  end

  @impl true
  def handle_frame({:binary, data}, state) do
    # Some implementations send raw binary audio
    if state.on_audio, do: state.on_audio.(data)
    {:ok, state}
  end

  defp handle_event(%{"type" => "audio.delta", "delta" => b64}, state) do
    audio = Base.decode64!(b64)
    if state.on_audio, do: state.on_audio.(audio)
    if state.on_event, do: state.on_event.(%{"type" => "audio.delta"})
    {:ok, state}
  end

  defp handle_event(%{"type" => "error", "message" => msg}, state) do
    if state.on_event, do: state.on_event.(%{"type" => "error", "message" => msg})
    {:close, state}
  end

  defp handle_event(event, state) do
    if state.on_event, do: state.on_event.(event)
    {:ok, state}
  end

  @impl true
  def handle_connect(_conn, state) do
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: {:local, _}}, state), do: {:ok, state}
  def handle_disconnect(%{reason: {:local, _, _}}, state), do: {:ok, state}

  def handle_disconnect(%{attempt_number: attempt}, state)
      when attempt > @max_reconnect_attempts do
    {:ok, state}
  end

  def handle_disconnect(%{attempt_number: attempt}, state) do
    backoff =
      min(@reconnect_base_backoff_ms * Integer.pow(2, attempt - 1), @reconnect_max_backoff_ms)

    Process.sleep(backoff)
    {:reconnect, state}
  end

  @impl WebSockex
  def handle_cast(:close, state) do
    {:close, state}
  end

  @impl WebSockex
  def handle_info(:close, state) do
    {:close, state}
  end

  # --- Pure helpers for testing ---

  @doc """
  Builds a text.delta event. Useful for testing and for users who want raw events.
  """
  @spec text_delta(String.t()) :: map()
  def text_delta(delta) when is_binary(delta) do
    %{"type" => "text.delta", "delta" => delta}
  end

  @doc "Builds a text.done event."
  def text_done, do: %{"type" => "text.done"}

  @doc "Builds a text.clear event for barge-in."
  def text_clear, do: %{"type" => "text.clear"}
end
