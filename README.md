# Xai

Native Elixir client for the xAI API (Grok).

- **gRPC** transport for chat, image, video, etc. (modeled after the official Python SDK).
- **WebSocket** support for realtime voice and streaming TTS.

This library aims to closely follow the official [Python xai-sdk](https://github.com/xai-org/xai-sdk-python) where possible.

> **Note**: For the OpenAI-compatible REST API only, consider using [req_llm](https://hex.pm/packages/req_llm).

## Status

**Active development**. Core pieces are implemented and the project compiles cleanly.

### Current

- ✅ `Xai.Client`
- ✅ `Xai.Chat` (create / append / sample / stream)
- ✅ `Xai.Video.generate/2` and `extend/2` (auto-polling)
- ✅ Real generated protobuf bindings for chat, video, image, sample, usage, deferred, and documents
- ⏳ auth, batch, embed, files, models, tokenize (need `google/rpc/status.proto`, not yet vendored) + Collections

## Installation

```elixir
def deps do
  [
    {:xai, "~> 0.1"}
  ]
end
```

## Quick Start

```elixir
client = Xai.Client.new(api_key: System.get_env("XAI_API_KEY"))

# Chat (blocking)
chat = Xai.Chat.create(client, model: "grok-4.5")
chat = Xai.Chat.append(chat, Xai.Chat.user("Explain quantum computing in one sentence."))
{:ok, response} = Xai.Chat.sample(chat)
[%{message: %{content: content}} | _] = response.outputs
IO.puts(content)

# Chat streaming (gRPC)
Xai.Chat.stream(chat)
|> Stream.each(fn chunk -> IO.write(Xai.Chat.extract_delta(chunk)) end)
|> Stream.run()

# Video (automatic polling, like the Python SDK)
{:ok, video} = Xai.Video.generate(client,
  prompt: "A serene lake at sunrise",
  model: "grok-imagine-video",
  duration: 5
)
IO.puts(video.url)
```

## WebSocket / Realtime (TTS & Voice)

xAI realtime features (streaming TTS and full-duplex voice agents) use WebSocket, not gRPC.

```elixir
{:ok, tts} = Xai.Realtime.connect_tts(
  api_key: System.get_env("XAI_API_KEY"),
  voice: "eve",
  codec: "mp3",
  on_audio: fn audio -> play(audio) end
)

Xai.Realtime.send_text(tts, "Hello from Elixir. ")
Xai.Realtime.send_text_done(tts)
```

For the full voice agent API (`/realtime`), use `Xai.Realtime.connect_realtime/1` and send/receive events.

See `Xai.Realtime` for details.

## Staying Close to the Official SDK

We use the public protobuf definitions from [xai-proto](https://github.com/xai-org/xai-proto) and mirror the high-level ergonomics of the Python SDK for gRPC parts. WebSocket support follows the documented JSON event protocol shown in the xAI docs.

See the Python SDK for the source of truth:
https://github.com/xai-org/xai-sdk-python

## Testing

### Running tests

```bash
# Fast unit tests (recommended for day-to-day development)
mix test --exclude integration
```

Integration tests are tagged with `:integration`. They are automatically skipped unless you provide credentials:

```bash
XAI_API_KEY=your_key mix test --only integration
```

### Testing strategy

- **Unit tests** run without network access or API keys. The gRPC client supports `connect: false` for tests that need a client struct without opening a real connection.
- **Mocking** is done with [Mox](https://hex.pm/packages/mox). A `Xai.RealtimeBehaviour` is provided so the WebSocket transport can be mocked.
- **Realtime (WebSocket)** code is tested via:
  - Pure helper functions (`text_delta/1`, `text_done/0`, etc.)
  - Direct invocation of `handle_frame/2` callbacks (no real WebSocket connection required)
- **Integration tests** exercise the live xAI API. They require a valid `XAI_API_KEY` and are skipped by default.

Current status (unit tests):

```bash
mix test --exclude integration
# 16 tests, 0 failures (1 excluded)
```

To run only a specific file or tag:

```bash
mix test test/xai/realtime_test.exs
mix test --only integration
```

## Development

### 1. Fetch the official protos (submodule)

```bash
git submodule update --init --recursive
```

### 2. Generate Elixir code

```bash
mix deps.get
mix proto.generate
```

`mix proto.generate` compiles the proto files listed in `@proto_files` in
`mix.exs` — see `AGENTS.md` for details and current coverage.

Run `mix quality` before committing — see `AGENTS.md` for what it checks.

See the [Testing](#testing) section above for how to run the test suite.

## License

Apache-2.0 (same as the official SDK and protos). See [LICENSE](LICENSE).
