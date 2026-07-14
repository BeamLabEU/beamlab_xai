defmodule Xai.RealtimeBehaviour do
  @moduledoc """
  Behaviour for the Realtime WebSocket client.

  This allows mocking the WebSocket layer in tests using Mox.
  """

  @type t :: pid() | term()
  @type opts :: keyword()
  @type event :: map()
  @type audio :: binary()

  @callback connect_tts(opts) :: {:ok, t()} | {:error, term()}
  @callback connect_realtime(opts) :: {:ok, t()} | {:error, term()}
  @callback send_text(t(), String.t()) :: :ok | {:error, term()}
  @callback send_text_done(t()) :: :ok | {:error, term()}
  @callback send_event(t(), event) :: :ok | {:error, term()}
  @callback close(t()) :: :ok
end
