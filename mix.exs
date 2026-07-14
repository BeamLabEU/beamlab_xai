defmodule Xai.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/beamlab-xai/xai"

  def project do
    [
      app: :xai,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Native Elixir gRPC client for the xAI API (Grok)",
      package: package(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # gRPC support
      {:grpc, "~> 1.0"},
      {:gun, "~> 2.0", override: true},
      {:grpc_server, "~> 1.0", only: [:dev, :test]}, # if we ever implement server parts

      # WebSocket support for realtime voice / TTS
      {:websockex, "~> 0.4"},
      {:jason, "~> 1.4"},

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
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      "proto.generate": ["protobuf.generate"],
      setup: ["deps.get", "proto.generate"]
    ]
  end
end
