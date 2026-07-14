# Run with: mix run examples/basic_chat.exs
# Requires XAI_API_KEY in env

Mix.install([{:xai, path: "."}])

client = Xai.Client.new()

chat = Xai.Chat.create(client, model: "grok-4.5")
chat = Xai.Chat.append(chat, Xai.Chat.user("Write a haiku about Elixir and gRPC."))

IO.puts("Sending request...")

case Xai.Chat.sample(chat) do
  {:ok, response} ->
    IO.puts("\nResponse:\n#{response.content}")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
