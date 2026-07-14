# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `Xai.Chat.stream/2` no longer crashes: it was calling `GRPC.Stub.recv/2` in a polling loop against a value that gRPC's server-streaming API already resolves to `{:ok, Enumerable.t()}` before it's returned, so `recv/2` had no matching clause and would raise.
- `Xai.Video.poll_for_video/4` was checking `if attempts <= 0, do: {:error, :timeout}` without an `else`; the result was discarded and the retry budget was never actually enforced. Rewritten as pattern-matched function heads.
- `Xai.Client.new/1` silently swallowed gRPC connection failures via `elem(connect(...), 1)`; a failed connect now raises with the real error instead of storing it as a bogus channel.
- `Xai.Chat.extract_delta/1` matched on `%{message: ...}`, but streamed chunks carry a `delta` key; it always returned `""`.
- `Xai.Client` connected with `ssl: [verify: :verify_none]` for the default TLS endpoint, disabling certificate verification. Now verifies peer certs against the system CA store.
- `Xai.Realtime.connect_tts/1` registered under a hardcoded `{:via, Registry, {Xai.RealtimeRegistry, :default}}` name, but that registry is never started — the first call would crash, and only one TTS connection could ever be alive at a time. Removed the vestigial naming.

### Changed
- Dropped the unused `grpc_server` dependency (and its transitive `flow`/`gen_stage`/`cowboy` tree), added for a server-side feature that was never implemented.
- Added `:inets` and `:ssl` to `extra_applications` (needed by the integration test's `:httpc` call and by TLS gRPC connections).
- Bumped minimum Elixir requirement from `~> 1.16` to `~> 1.18`.
- Replaced direct `Jason` usage with the built-in `JSON` module (Elixir 1.18+) in `Xai.Realtime` and the integration test; dropped the direct `jason` dependency. `jason` still appears in `mix.lock` as a transitive dependency (`grpc_core`, `protobuf`, and `credo` each require it directly), but our own code no longer calls it.

## [0.1.0] - 2026-07-14

### Added
- Initial release of the xAI Elixir SDK.
- gRPC client implementation using the official xAI protobuf definitions (via `priv/xai_proto` submodule).
- High-level API:
  - `Xai.Client` – core client for gRPC connections.
  - `Xai.Chat` – chat completions with support for messages, streaming, and reasoning.
  - `Xai.Video` – image and video generation with automatic polling for async operations.
- WebSocket support for realtime features via `websockex`:
  - Streaming Text-to-Speech (TTS).
  - Realtime Voice Agent API.
- Protobuf code generation setup (`.protobuf.exs` + `mix proto.generate` alias).
- Comprehensive test suite:
  - Unit tests (no network required).
  - Integration tests (gated behind `XAI_API_KEY`).
  - Use of Mox for mocking.
- Documentation:
  - README with quick start, architecture notes, and testing instructions.
  - `AGENTS.md` for AI coding agents.
- Development tooling:
  - Gitignored `scripts/test_with_key.sh` for convenient local integration testing.
  - Proper handling of generated protobuf code (not committed).

### Changed
- N/A (initial release).

### Fixed
- N/A (initial release).

### Security
- API keys are never committed. Integration tests require the `XAI_API_KEY` environment variable.