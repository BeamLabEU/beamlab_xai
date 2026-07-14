# mix run examples/video.exs

client = Xai.Client.new(api_key: System.get_env("XAI_API_KEY"))

IO.puts("Generating video...")

case Xai.Video.generate(client,
       prompt: "A peaceful mountain lake at dawn with mist",
       model: "grok-imagine-video",
       duration: 4
     ) do
  {:ok, video} ->
    IO.puts("Done! #{video.url}")

  {:error, reason} ->
    IO.puts("Failed: #{inspect(reason)}")
end
