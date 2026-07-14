# AGENTS.md

This document provides guidance for AI coding agents working on the **xai** Elixir library (the native gRPC + WebSocket client for the xAI/Grok API).

## Project Goals

- Provide a first-class, native Elixir experience for the xAI API.
- Primary transport: **gRPC** using the official protobuf definitions.
- Realtime features (voice agents, streaming TTS): **WebSocket** (via `websockex`).
- Stay reasonably close to the official Python `xai-sdk` API shape and behavior.

## Project Setup

### 1. Initialize the proto submodule (required)

```bash
git submodule update --init --recursive
```

### 2. Install dependencies and generate code

```bash
mix deps.get
mix proto.generate          # alias for `mix protobuf.generate`
```

Generated code lands in `lib/xai/proto/`. **Never commit these files** — they are gitignored.

## Common Commands

| Command | Purpose |
|---------|---------|
| `mix quality` | **Run this before committing/pushing.** Chains format check, `compile --warnings-as-errors`, `deps.unlock --check-unused`, `credo --strict`, unit tests, and `dialyzer`. Must be green. |
| `mix quality.audit` | Checks dependencies for known security advisories (`mix hex.audit`). Not part of `mix quality` — it can fail for reasons outside this repo's control (an unpatched CVE upstream); run it periodically, not as a commit gate. |
| `mix test --exclude integration` | Run fast unit tests (default) |
| `mix test --only integration` | Run live tests against the real API (requires `XAI_API_KEY`) |
| `mix proto.generate` | Regenerate Elixir code from the xAI protos |
| `mix format` / `mix format --check-formatted` | Format / verify formatting (see `.formatter.exs` — `lib/xai/proto/` is intentionally excluded, it's generated) |
| `mix credo --strict` | Run linting (`.credo.exs` excludes `lib/xai/proto/`) |
| `mix dialyzer` | Run static type analysis (`.dialyzer_ignore.exs` documents the currently-accepted findings and why) |
| `mix docs` | Build documentation |

As of this writing, `mix quality.audit` reports advisories against `cowlib` (pulled in transitively via `gun`, used for gRPC's HTTP/2 transport) with no fixed release available yet — nothing to act on until upstream patches it. Re-check periodically.

### Running with a real key (local only)

Use the gitignored helper:

```bash
./scripts/test_with_key.sh
./scripts/test_with_key.sh --max-failures 1 -v
```

**Never** commit or share real API keys.

## Important Rules

### Do not commit generated code
- `lib/xai/proto/` must stay gitignored.
- Always run `mix proto.generate` after pulling changes or modifying `.protobuf.exs`.

### Do not commit secrets
- `scripts/test_with_key.sh` is intentionally gitignored.
- Never add real `XAI_API_KEY` values to source, tests, or examples.

### Testing guidelines

- Unit tests **must not** require network access or API keys.
- Use `connect: false` when constructing `Xai.Client` in tests:
  ```elixir
  client = Xai.Client.new(api_key: "test", connect: false)
  ```
- Use **Mox** for mocking external behavior.
- A `Xai.RealtimeBehaviour` exists for mocking the WebSocket layer.
- Integration tests must be tagged with `@tag :integration` and will be skipped without a key.

### Realtime / WebSocket

- Realtime features (TTS, voice) are intentionally separate from the main gRPC client.
- Test realtime logic using pure helpers (`text_delta/1`, etc.) and direct `handle_frame/2` calls when possible.
- Do not assume gRPC and WebSocket share the same connection model.

## Code Organization

```
lib/
  xai/
    client.ex                 # Core gRPC client
    chat.ex                   # High-level chat (gRPC)
    video.ex                  # Image/video generation (gRPC)
    realtime.ex               # WebSocket client for TTS/voice
    realtime_behaviour.ex     # Behaviour for mocking realtime
  xai.ex                      # Public API surface

lib/xai/proto/                # GENERATED - do not edit or commit
priv/xai_proto/               # Git submodule (official protos)
```

High-level modules (`Xai.Chat`, `Xai.Video`, etc.) wrap the generated `XaiApi.*` / `Proto.*` modules. Prefer extending the high-level API.

## When Making Changes

1. Run `mix proto.generate` if you touched anything related to protobufs.
2. Add or update unit tests that do **not** require a key.
3. Tag any new live tests with `@tag :integration`.
4. Run `mix quality` before committing.
5. Update the README when changing public API or setup steps.
6. Keep the library close to the Python SDK's mental model where it makes sense.

## Useful Files

- `.protobuf.exs` — configuration for protobuf code generation
- `priv/protos/README.md` — notes on the proto submodule
- `test/test_helper.exs` — test setup and Mox mocks
- `scripts/test_with_key.sh` — local helper (gitignored)
- `.formatter.exs` — formatter input globs (excludes generated `lib/xai/proto/`)
- `.credo.exs` — lint config (excludes generated `lib/xai/proto/`)
- `.dialyzer_ignore.exs` — documented, accepted dialyzer findings; each entry explains why

## Questions to Ask Before Coding

- Does this change require regenerating protos?
- Should this be gRPC or WebSocket?
- Can this be tested without a real API key?
- Does this match the style and intent of the official Python SDK?