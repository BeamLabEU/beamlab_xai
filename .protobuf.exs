# Configuration for `mix protobuf.generate`
# Run after adding the submodule:
#   git submodule add https://github.com/xai-org/xai-proto priv/xai_proto
#   git submodule update --init --recursive

[
  # Include paths for imports (googleapis, etc. are often needed)
  imports: [
    "priv/xai_proto/proto",
    "priv/xai_proto"
  ],

  # Paths containing the .proto files we want to compile
  paths: [
    "priv/xai_proto/proto/xai/api/v1"
  ],

  # Use the gRPC plugin so we get both messages + service stubs
  plugins: [ProtobufGenerate.Plugins.GRPCWithOptions],

  # Where to write the generated Elixir modules
  output_path: "lib/xai/proto",

  # Generate descriptors (sometimes useful)
  generate_descriptors: true,

  # Add any extra options here as needed
  extra_options: "--elixir"
]