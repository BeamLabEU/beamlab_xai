# Protobufs for xAI

This project uses the official xAI protobuf definitions for gRPC.

## Recommended Setup

```bash
# From the project root
git submodule add https://github.com/xai-org/xai-proto priv/xai_proto
git submodule update --init --recursive
mix deps.get
mix protobuf.generate
```

## Generation Configuration

The generation is configured in the root `.protobuf.exs` file.

Generated modules will land in `lib/xai/proto/`.

After generation you will get modules like:

- `Xai.Proto.Chat`
- `Xai.Proto.Chat.Stub`
- `Xai.Proto.Video`
- etc.

See the main `README.md` for how the high-level API (`Xai.Client`, `Xai.Chat`, ...) wraps these.
