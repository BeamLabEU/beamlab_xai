defmodule Xai do
  @moduledoc """
  Native Elixir client for the xAI API (Grok).

  - gRPC transport for chat, image, video, etc.
  - WebSocket transport for realtime voice and streaming TTS.

  Stays close to the official Python `xai-sdk` where possible.

  ## Quick Example (gRPC)

      client = Xai.Client.new(api_key: System.get_env("XAI_API_KEY"))

      chat = Xai.Chat.create(client, model: "grok-4.5")
      chat = Xai.Chat.append(chat, Xai.Chat.user("Hello!"))
      {:ok, resp} = Xai.Chat.sample(chat)

  ## Streaming TTS (WebSocket)

      {:ok, tts} = Xai.Realtime.connect_tts(
        api_key: System.get_env("XAI_API_KEY"),
        voice: "eve",
        on_audio: fn audio -> play(audio) end
      )

      Xai.Realtime.send_text(tts, "Hello from Elixir")
      Xai.Realtime.send_text_done(tts)

  See `Xai.Client`, `Xai.Chat`, `Xai.Video`, and `Xai.Realtime`.
  """

  def version do
    Application.spec(:xai, :vsn) |> to_string()
  end
end


