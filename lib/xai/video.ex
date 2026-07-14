defmodule Xai.Video do
  @moduledoc """
  Video generation (Imagine API) via gRPC.

  Mirrors `client.video` in the official Python xai-sdk.
  The high-level functions automatically handle the deferred/poll pattern.
  """

  alias XaiApi, as: Proto

  @doc """
  Generate a video.

  Example:

      {:ok, video} = Xai.Video.generate(client,
        prompt: "A cat on a skateboard",
        model: "grok-imagine-video",
        duration: 5
      )
  """
  @spec generate(Xai.Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate(client, opts) do
    timeout = Keyword.get(opts, :timeout, Xai.Client.default_timeout(client))

    request = %Proto.GenerateVideoRequest{
      prompt: Keyword.fetch!(opts, :prompt),
      model: Keyword.get(opts, :model, "grok-imagine-video"),
      duration: Keyword.get(opts, :duration),
      # aspect_ratio and resolution are enums in the proto
      # for simplicity we can pass atoms or integers; the generator handles some
    }

    metadata = Xai.Client.auth_metadata(client)

    case Proto.Video.Stub.generate_video(client.channel, request, timeout: timeout, metadata: metadata) do
      {:ok, %Proto.StartDeferredResponse{request_id: rid}} when is_binary(rid) ->
        poll_for_video(client, rid, timeout)

      {:ok, resp} ->
        {:ok, resp}

      other ->
        other
    end
  end

  @doc "Extend a video"
  @spec extend(Xai.Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def extend(client, opts) do
    request = %Proto.ExtendVideoRequest{
      prompt: Keyword.fetch!(opts, :prompt),
      model: Keyword.get(opts, :model),
      video: %Proto.VideoUrlContent{url: Keyword.fetch!(opts, :video_url)}
    }

    metadata = Xai.Client.auth_metadata(client)

    case Proto.Video.Stub.extend_video(client.channel, request, metadata: metadata) do
      {:ok, %Proto.StartDeferredResponse{request_id: rid}} ->
        poll_for_video(client, rid, Xai.Client.default_timeout(client))

      other -> other
    end
  end

  defp poll_for_video(client, request_id, timeout, attempts \\ 60) do
    if attempts <= 0, do: {:error, :timeout}

    req = %Proto.GetDeferredVideoRequest{request_id: request_id}
    metadata = Xai.Client.auth_metadata(client)

    case Proto.Video.Stub.get_deferred_video(client.channel, req, metadata: metadata) do
      {:ok, %Proto.GetDeferredVideoResponse{status: :DONE, response: resp}} ->
        {:ok, resp}

      {:ok, %Proto.GetDeferredVideoResponse{status: :FAILED}} ->
        {:error, :failed}

      {:ok, _still_running} ->
        Process.sleep(1500)
        poll_for_video(client, request_id, timeout, attempts - 1)

      err -> err
    end
  end
end

