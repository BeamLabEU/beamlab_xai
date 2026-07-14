defmodule Xai.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/beamlab-xai/xai"

  # The xai-proto v1 files actually used by Xai.Chat / Xai.Video (+ documents.proto,
  # which chat.proto's CollectionsSearch depends on). auth/batch/embed/files/models/
  # tokenize aren't generated yet — they additionally need google/rpc/status.proto,
  # which isn't vendored anywhere in this repo yet.
  @proto_files ~w(
    xai/api/v1/chat.proto
    xai/api/v1/video.proto
    xai/api/v1/image.proto
    xai/api/v1/sample.proto
    xai/api/v1/usage.proto
    xai/api/v1/deferred.proto
    xai/api/v1/documents.proto
  )

  def project do
    [
      app: :xai,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Native Elixir gRPC client for the xAI API (Grok)",
      package: package(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # `mix quality` chains `mix test`, so it must run under MIX_ENV=test.
  def cli do
    [preferred_envs: [quality: :test, "quality.audit": :test]]
  end

  defp deps do
    [
      # gRPC support
      {:grpc, "~> 1.0"},
      # Both HTTP/2 adapters are optional, matching `grpc`'s own upstream
      # pattern (see GRPC.Client.Adapters.Gun / .Mint) — a consumer using
      # only `Xai.Realtime` (WebSocket, via websockex) needs neither, and
      # a consumer using `Xai.Chat`/`Xai.Video` picks one by adding it to
      # their own deps and passing `adapter:` to `Xai.Client.new/1` (Gun
      # remains the default when unspecified — add `{:gun, "~> 2.0"}` to
      # keep the pre-0.2 default behavior; `{:mint, "~> 1.9"}` avoids
      # `:cowlib` entirely). This repo lists both (below) so its own
      # tests/dialyzer exercise both adapters.
      {:gun, "~> 2.0", optional: true},
      {:mint, "~> 1.9", optional: true},

      # WebSocket support for realtime voice / TTS
      {:websockex, "~> 0.4"},

      # Protobuf support and generation
      {:protobuf, "~> 0.17"},
      {:protobuf_generate, "~> 0.2", only: [:dev, :test]},

      # Optional but recommended
      {:telemetry, "~> 1.0"},

      # Dev/test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # Testing
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["beamlab-xai"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "xAI Docs" => "https://docs.x.ai/",
        "Python SDK" => "https://github.com/xai-org/xai-sdk-python"
      },
      # Explicit allowlist: Hex's default ["lib", "priv", ...] would otherwise
      # sweep in priv/xai_proto, the ~160KB vendored xai-proto git submodule
      # (raw .proto sources, buf tooling, CI configs) that consumers of the
      # compiled package have no use for.
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      # `protobuf_generate` 0.2.1's `protobuf.generate` task takes CLI flags,
      # not a config file — there is no `.protobuf.exs` to read. This is the
      # single source of truth for how xai-proto gets compiled; update
      # @proto_files above to add coverage.
      "proto.generate": [
        "protobuf.generate --include-path=priv/xai_proto/proto " <>
          "--plugin=ProtobufGenerate.Plugins.GRPCWithOptions " <>
          "--output-path=lib/xai/proto " <>
          Enum.join(@proto_files, " ")
      ],
      setup: ["deps.get", "proto.generate"],
      # The required gate: keep this green before committing/pushing.
      # Ordered cheapest-and-most-likely-to-fail first so it fails fast.
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors --force",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --exclude integration",
        "dialyzer"
      ],
      # Separate from `quality` because it can fail for reasons outside our
      # control (an unpatched CVE in a transitive dependency) — run it
      # periodically rather than gating every commit on it.
      "quality.audit": ["hex.audit"]
    ]
  end
end
