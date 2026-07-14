[
  # GRPC.Stub.connect/2's own success typing (in the `grpc` dependency) can't
  # prove its {:ok, channel} branch reachable, even though its @spec and docs
  # say it's possible and it's the path a real successful connect takes. This
  # predates our error-handling fix in Xai.Client.maybe_connect/3 — removing
  # our `case` would just hide the warning by no longer checking the result.
  {"lib/xai/client.ex", "The pattern can never match the type {:error, _}."}
]
