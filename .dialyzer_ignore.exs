[
  # GRPC.Stub.connect/2's own success typing (in the `grpc` dependency) can't
  # prove its {:ok, channel} branch reachable, even though its @spec and docs
  # say it's possible and it's the path a real successful connect takes. This
  # predates our error-handling fix in Xai.Client.maybe_connect/3 — removing
  # our `case` would just hide the warning by no longer checking the result.
  {"lib/xai/client.ex", "The pattern can never match the type {:error, _}."},

  # lib/xai/proto/**/*.pb.ex are hand-written stand-ins for the real output of
  # `mix proto.generate` (see AGENTS.md / README "simulated protos" note) and
  # are gitignored. They reference message types (SamplingUsage,
  # HybridRetrieval, KeywordRetrieval, SemanticRetrieval) that live in .proto
  # files this stand-in set doesn't cover yet. Re-run
  # `mix dialyzer --format ignore_file_strict` after wiring up the real
  # submodule + codegen to confirm these are gone.
  {"lib/xai/proto/xai/api/v1/chat.pb.ex", "Unknown type: XaiApi.SamplingUsage.t/0."},
  {"lib/xai/proto/xai/api/v1/chat.pb.ex", "Unknown type: XaiApi.HybridRetrieval.t/0."},
  {"lib/xai/proto/xai/api/v1/chat.pb.ex", "Unknown type: XaiApi.KeywordRetrieval.t/0."},
  {"lib/xai/proto/xai/api/v1/chat.pb.ex", "Unknown type: XaiApi.SemanticRetrieval.t/0."},
  {"lib/xai/proto/xai/api/v1/image.pb.ex", "Unknown type: XaiApi.SamplingUsage.t/0."},
  {"lib/xai/proto/xai/api/v1/video.pb.ex", "Unknown type: XaiApi.SamplingUsage.t/0."}
]
