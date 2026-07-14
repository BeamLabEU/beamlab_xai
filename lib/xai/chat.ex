defmodule Xai.Chat do
  @moduledoc """
  High-level chat interface, modeled after `client.chat` in the official
  Python xai-sdk.

  ## Example

      client = Xai.Client.new(api_key: System.get_env("XAI_API_KEY"))

      chat = Xai.Chat.create(client, model: "grok-4.5")
      chat = Xai.Chat.append(chat, Xai.Chat.user("Hello from Elixir!"))

      {:ok, response} = Xai.Chat.sample(chat)
      IO.puts(response.outputs |> hd() |> Map.get(:message) |> Map.get(:content))
  """

  alias XaiApi, as: Proto
  alias XaiApi.Chat.Stub, as: ChatStub

  defstruct [:client, :model, messages: [], opts: []]

  @type t :: %__MODULE__{
          client: Xai.Client.t(),
          model: String.t(),
          messages: [map()],
          opts: keyword()
        }

  @doc "Create a new chat session."
  @spec create(Xai.Client.t(), keyword()) :: t()
  def create(client, opts) do
    model = Keyword.fetch!(opts, :model)

    %__MODULE__{
      client: client,
      model: model,
      messages: [],
      opts: Keyword.drop(opts, [:model])
    }
  end

  @doc "Append a message. Pass a string for a simple user message."
  @spec append(t(), String.t() | map()) :: t()
  def append(%__MODULE__{} = chat, text) when is_binary(text) do
    append(chat, user(text))
  end

  def append(%__MODULE__{messages: msgs} = chat, msg) when is_map(msg) do
    %{chat | messages: msgs ++ [msg]}
  end

  @doc "Build a user message"
  def user(text) do
    %Proto.Message{
      role: :ROLE_USER,
      content: [%Proto.Content{content: {:text, text}}]
    }
  end

  @doc "Build a system message"
  def system(text) do
    %Proto.Message{
      role: :ROLE_SYSTEM,
      content: [%Proto.Content{content: {:text, text}}]
    }
  end

  @doc "Send the messages and get a full response."
  @spec sample(t(), keyword()) :: {:ok, Proto.GetChatCompletionResponse.t()} | {:error, term()}
  def sample(%__MODULE__{client: client, model: model, messages: messages}, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, Xai.Client.default_timeout(client))

    request = %Proto.GetCompletionsRequest{
      model: model,
      messages: messages
    }

    metadata = Xai.Client.auth_metadata(client)

    ChatStub.get_completion(client.channel, request,
      timeout: timeout,
      metadata: metadata
    )
  end

  @doc """
  Returns a Stream of completion chunks for real-time streaming (gRPC server streaming).

  Mirrors the Python `chat.stream()`.

  Usage:

      Xai.Chat.stream(chat)
      |> Stream.each(fn chunk ->
        # chunk is %XaiApi.GetChatCompletionChunk{}
        IO.write(extract_delta(chunk))
      end)
      |> Stream.run()
  """
  @spec stream(t(), keyword()) :: Enumerable.t()
  def stream(%__MODULE__{client: client, model: model, messages: messages}, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, Xai.Client.default_timeout(client))

    request = %Proto.GetCompletionsRequest{
      model: model,
      messages: messages
    }

    metadata = Xai.Client.auth_metadata(client)

    case ChatStub.get_completion_chunk(
           client.channel,
           request,
           timeout: timeout,
           metadata: metadata
         ) do
      {:ok, chunk_stream} ->
        Stream.map(chunk_stream, fn
          {:ok, chunk} -> chunk
          {:error, reason} -> raise "chat stream error: #{inspect(reason)}"
        end)

      {:error, reason} ->
        raise "failed to start chat stream: #{inspect(reason)}"
    end
  end

  @doc "Helper to pull text delta from a chunk (adjust as the chunk shape evolves)."
  def extract_delta(%Proto.GetChatCompletionChunk{outputs: outputs}) do
    outputs
    |> List.first()
    |> case do
      %{delta: %{content: content}} when is_binary(content) -> content
      _ -> ""
    end
  end

  def extract_delta(_), do: ""
end
