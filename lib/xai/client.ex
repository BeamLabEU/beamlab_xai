defmodule Xai.Client do
  @moduledoc """
  The main client for interacting with xAI's gRPC APIs.

  Closely modeled after `xai_sdk.Client` in the official Python SDK.

  ## Example

      client = Xai.Client.new(api_key: System.get_env("XAI_API_KEY"))

      chat = Xai.Chat.create(client, model: "grok-4.5")
      chat = Xai.Chat.append(chat, Xai.Chat.user("Hello"))
      {:ok, response} = Xai.Chat.sample(chat)

  For long-running operations (video, deferred), the client manages the channel.

  ## Options

  * `:api_key` - falls back to `XAI_API_KEY`
  * `:management_api_key` - for Collections / management (falls back to `XAI_MANAGEMENT_API_KEY`)
  * `:endpoint` - default "api.x.ai:443"
  * `:timeout` - default 30 minutes
  """

  defstruct [:channel, :api_key, :management_api_key, :endpoint, :timeout]

  @type t :: %__MODULE__{
          channel: GRPC.Channel.t(),
          api_key: String.t() | nil,
          management_api_key: String.t() | nil,
          endpoint: String.t(),
          timeout: pos_integer()
        }

  @default_endpoint "api.x.ai:443"
  @default_timeout :timer.minutes(30)

  @doc """
  Create a new client.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    api_key =
      Keyword.get(opts, :api_key) ||
        System.get_env("XAI_API_KEY") ||
        raise ArgumentError, "api_key is required (or set XAI_API_KEY)"

    management_key =
      Keyword.get(opts, :management_api_key) || System.get_env("XAI_MANAGEMENT_API_KEY")

    endpoint = Keyword.get(opts, :endpoint, @default_endpoint)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    channel =
      case Keyword.get(opts, :channel) do
        nil -> maybe_connect(endpoint, api_key, Keyword.get(opts, :connect, true))
        channel -> channel
      end

    %__MODULE__{
      channel: channel,
      api_key: api_key,
      management_api_key: management_key,
      endpoint: endpoint,
      timeout: timeout
    }
  end

  @doc "Get the raw gRPC channel (for advanced use or direct stub calls)."
  @spec channel(t()) :: GRPC.Channel.t()
  def channel(%__MODULE__{channel: ch}), do: ch

  @doc "Get the configured default timeout."
  def default_timeout(%__MODULE__{timeout: t}), do: t

  # Internal: build metadata for calls that need it
  @doc false
  def auth_metadata(%__MODULE__{api_key: key}) when is_binary(key) do
    [{"authorization", "Bearer #{key}"}]
  end

  def auth_metadata(_), do: []

  defp maybe_connect(_endpoint, _api_key, false), do: nil

  defp maybe_connect(endpoint, api_key, true) do
    case connect(endpoint, api_key) do
      {:ok, channel} ->
        channel

      {:error, reason} ->
        raise "failed to connect to xAI gRPC endpoint #{endpoint}: #{inspect(reason)}"
    end
  end

  defp connect(endpoint, api_key) do
    cred =
      if String.ends_with?(endpoint, ":443") do
        GRPC.Credential.new(ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()])
      else
        nil
      end

    opts = [
      cred: cred,
      headers: auth_headers(api_key)
    ]

    GRPC.Stub.connect(endpoint, opts)
  end

  defp auth_headers(nil), do: []
  defp auth_headers(key), do: [{"authorization", "Bearer #{key}"}]
end
