[
  # Deliberately empty.
  #
  # This held one entry: `GRPC.Stub.connect/2`'s success typing in grpc 1.0.2
  # could not prove its `{:ok, channel}` branch reachable, so the `case` in
  # `Xai.Client.maybe_connect/3` — which does check the result — was reported
  # as an impossible match. grpc 1.0.3 fixed that typing, and dialyzer now
  # reports the entry itself as an unnecessary skip. Removed rather than left
  # in place: a stale ignore is an ignore that will one day silence a real
  # warning matching the same string.
]
