# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-14

### Changed
- **`:gun` is now an optional dependency; `:mint` is a new optional alternative.** Previously `xai` hard-required `gun` (and its transitive `cowlib` dependency) for every consumer, even ones that only use `Xai.Realtime` (WebSocket, via `websockex` — no gun/cowlib involved at all). `Xai.Client.new/1` now accepts an `:adapter` option threaded through to `GRPC.Stub.connect/2` (mirrors `grpc`'s own `GRPC.Client.Adapters.Gun` / `.Mint` split); Gun remains the default when unspecified for backward compatibility.
  - **Breaking for `Xai.Chat` / `Xai.Video` users**: add `{:gun, "~> 2.0"}` to your own `mix.exs` to keep the previous default behavior (it's no longer pulled in transitively). Or add `{:mint, "~> 1.9"}` and pass `adapter: GRPC.Client.Adapters.Mint` — Mint has no `:cowlib` in its dependency tree at all.
  - **No change needed for `Xai.Realtime`-only users** (e.g. streaming TTS) — that path never depended on gun/cowlib and still doesn't.

## [0.1.1] - 2026-07-14

### Fixed
- `Xai.Realtime.close/1` no longer crashes the connection process: no `handle_cast/2`
  clause was defined for the `:close` cast it sends, so it fell through to
  `use WebSockex`'s default (raising) implementation. Added the missing clause.
- `Xai.Realtime.handle_disconnect/2` no longer unconditionally reconnects. It now
  terminates cleanly on a locally-initiated close (`close/1`, or the internal
  "error" event handler) and applies capped exponential backoff (500ms up to 30s,
  giving up after 5 attempts) on genuine remote/error disconnects, instead of
  hot-looping forever on e.g. a persistent auth failure.
- `Xai.Video.generate/2` no longer silently drops `:aspect_ratio` and `:resolution`
  options — they're now passed through to `GenerateVideoRequest`.
- `Xai.Video.extend/2` now passes `:timeout` to the gRPC call and to polling
  (from `opts` or the client's configured default), matching `generate/2` instead
  of always falling back to the gRPC library's own default.
- `Xai.Client` no longer infers TLS from `String.ends_with?(endpoint, ":443")`
  (silently dropping to plaintext — and sending the Bearer API key unencrypted —
  for any custom endpoint on a non-`:443` port). TLS is now controlled by an
  explicit `:ssl` option, defaulting to `true`.

### Added
- Test coverage for `Xai.Realtime.handle_cast/2` (`:close`) and `handle_disconnect/2`
  (local-close termination, reconnect, and attempt-cap termination), previously
  untested.
- `Xai.Video.build_generate_request/1` and `build_extend_request/1` extracted as
  testable helpers, with tests covering the `:aspect_ratio`/`:resolution` fix above
  (`test/xai/video_test.exs` was previously a placeholder with no real assertions).

## [0.1.0] - 2026-07-14

First published release — nothing shipped to Hex before this version, so
everything below (including the initial implementation) is folded into it.

### Added
- Initial implementation of the xAI Elixir SDK:
  - `Xai.Client` – core client for gRPC connections.
  - `Xai.Chat` – chat completions with support for messages, streaming, and reasoning.
  - `Xai.Video` – image and video generation with automatic polling for async operations.
  - WebSocket support for realtime features via `websockex` (streaming TTS, voice agent API).
- Real generated protobuf bindings (via `mix proto.generate`, see below) for chat, video,
  image, sample, usage, deferred, and documents — replacing the hand-written placeholder
  structs the implementation started from.
- `LICENSE` (Apache-2.0, matching the `mix.exs` declaration).
- `mix quality`: a single gate that chains `format --check-formatted`, `compile --warnings-as-errors`,
  `deps.unlock --check-unused`, `credo --strict`, unit tests, and `dialyzer`. Run it before committing/pushing.
- `mix quality.audit`: `mix hex.audit` as a separate, non-gating alias — it can fail for reasons
  outside this repo's control (an unpatched upstream CVE), so it isn't part of `mix quality`.
- `.formatter.exs`, `.credo.exs` (both exclude the generated, gitignored `lib/xai/proto/`), and
  `.dialyzer_ignore.exs` (documents each currently-accepted dialyzer finding and why).
- Test suite: unit tests (no network required), integration tests (gated behind `XAI_API_KEY`),
  Mox-based mocking.
- `AGENTS.md` for AI coding agents.

### Fixed
- `Xai.Chat.stream/2` no longer crashes: it was calling `GRPC.Stub.recv/2` in a polling loop
  against a value that gRPC's server-streaming API already resolves to `{:ok, Enumerable.t()}`
  before it's returned, so `recv/2` had no matching clause and would raise.
- `Xai.Video`'s private `poll_for_video/4` was checking `if attempts <= 0, do: {:error, :timeout}`
  without an `else`; the result was discarded and the retry budget was never actually enforced.
  Rewritten as pattern-matched function heads.
- `Xai.Client.new/1` silently swallowed gRPC connection failures via `elem(connect(...), 1)`;
  a failed connect now raises with the real error instead of storing it as a bogus channel.
- `Xai.Chat.extract_delta/1` matched on `%{message: ...}`, but streamed chunks carry a `delta`
  key; it always returned `""`.
- `Xai.Client` connected with `ssl: [verify: :verify_none]` for the default TLS endpoint,
  disabling certificate verification. Now verifies peer certs against the system CA store.
- `Xai.Realtime.connect_tts/1` registered under a hardcoded
  `{:via, Registry, {Xai.RealtimeRegistry, :default}}` name, but that registry is never
  started — the first call would crash, and only one TTS connection could ever be alive at a
  time. Removed the vestigial naming.
- `mix proto.generate` never actually worked: `.protobuf.exs` was never read by anything (the
  installed `protobuf_generate` version takes CLI flags, not a config file). Replaced with a
  working alias in `mix.exs` (`@proto_files` + explicit flags) and regenerated real bindings
  from the `priv/xai_proto` submodule.
- README's Quick Start examples referenced `response.content` and an undefined `extract_text/1`
  that don't match the real generated response shape; fixed to use
  `response.outputs |> hd() |> ...` and `Xai.Chat.extract_delta/1`.
- `mix hex.build`/`hex.publish` would have failed outright (`Can't build package with
  overridden dependency gun`); removed the unnecessary `override: true` on the `gun` dep — it
  wasn't resolving a real conflict (`~> 2.0` already satisfies `grpc`'s own `~> 2.4.0`).
- `package[:files]` wasn't set, so Hex's default (`lib`, `priv`, ...) would have swept the
  ~160KB vendored `priv/xai_proto` git submodule (raw `.proto` sources, buf tooling, CI
  configs) into the published package. Now an explicit allowlist.

### Changed
- Dropped the unused `grpc_server` dependency (and its transitive `flow`/`gen_stage`/`cowboy`
  tree), added for a server-side feature that was never implemented.
- Added `:inets` and `:ssl` to `extra_applications` (needed by the integration test's `:httpc`
  call and by TLS gRPC connections).
- Bumped minimum Elixir requirement from `~> 1.16` to `~> 1.18`.
- Replaced direct `Jason` usage with the built-in `JSON` module (Elixir 1.18+) in
  `Xai.Realtime` and the integration test; dropped the direct `jason` dependency. `jason`
  still appears in `mix.lock` as a transitive dependency (`grpc_core`, `protobuf`, and
  `credo` each require it directly), but our own code no longer calls it.
- Aliased the generated gRPC stub modules locally in `Xai.Chat`/`Xai.Video` instead of reaching
  through the nested `Proto.Chat.Stub`/`Proto.Video.Stub` path, clearing Credo's strict-mode
  design suggestions.

### Security
- API keys are never committed. Integration tests require the `XAI_API_KEY` environment variable.