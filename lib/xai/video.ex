defmodule Xai.Video do
  @moduledoc """
  Video generation (Imagine API) via gRPC.

  Mirrors `client.video` in the official Python xai-sdk.
  The high-level functions automatically handle the deferred/poll pattern.

  ## Options

  Option names follow the Python SDK's `client.video.generate`.

    * `:prompt` (required), `:model`, `:duration`
    * `:aspect_ratio` - `"16:9"`, `"9:16"`, `"1:1"`, `"4:3"`, `"3:4"`, `"3:2"`, `"2:3"`
      (or the proto atom, e.g. `:VIDEO_ASPECT_RATIO_16_9`)
    * `:resolution` - `"480p"`, `"720p"`, `"1080p"` (or the proto atom)
    * `:image_url` / `:image_file_id` - first frame (image-to-video)
    * `:last_frame_url` / `:last_frame_file_id` - last frame
    * `:keyframes` - `[%{image_url: url, timestamp: 2.5}, %{image_file_id: id, timestamp: 4}]`
    * `:video_url` / `:video_file_id` - source video (editing)
    * `:reference_image_urls` / `:reference_image_file_ids` - style/content references
    * `:reference_audios` - `[%{voice_id: "ara"}]`
    * `:generate_audio` - generate audio with the video
    * `:storage_options` - store the result in the Files API:
      `%{filename: "clip.mp4", expires_after: 3600, public_url: true}`
      (`public_url` may also be `%{expires_after: seconds}`)
    * `:timeout` - per-request timeout

  Within each URL/file-ID pair only one may be given; both raises `ArgumentError`.
  `extend/2` accepts `:prompt`, `:model`, `:duration`, `:video_url` or
  `:video_file_id`, and `:storage_options`.
  """

  alias XaiApi, as: Proto
  alias XaiApi.Video.Stub, as: VideoStub

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
    request = build_generate_request(opts)
    metadata = Xai.Client.auth_metadata(client)

    case VideoStub.generate_video(client.channel, request,
           timeout: timeout,
           metadata: metadata
         ) do
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
    timeout = Keyword.get(opts, :timeout, Xai.Client.default_timeout(client))
    request = build_extend_request(opts)
    metadata = Xai.Client.auth_metadata(client)

    case VideoStub.extend_video(client.channel, request, timeout: timeout, metadata: metadata) do
      {:ok, %Proto.StartDeferredResponse{request_id: rid}} ->
        poll_for_video(client, rid, timeout)

      other ->
        other
    end
  end

  @doc false
  @spec build_generate_request(keyword()) :: Proto.GenerateVideoRequest.t()
  def build_generate_request(opts) do
    check_exclusive!(opts, :image_url, :image_file_id)
    check_exclusive!(opts, :video_url, :video_file_id)
    check_exclusive!(opts, :last_frame_url, :last_frame_file_id)

    %Proto.GenerateVideoRequest{
      prompt: Keyword.fetch!(opts, :prompt),
      model: Keyword.get(opts, :model, "grok-imagine-video"),
      image: image_content(opts[:image_url], opts[:image_file_id]),
      video: video_content(opts[:video_url], opts[:video_file_id]),
      last_frame: image_content(opts[:last_frame_url], opts[:last_frame_file_id]),
      keyframes: Enum.map(Keyword.get(opts, :keyframes, []), &keyframe/1),
      duration: Keyword.get(opts, :duration),
      aspect_ratio: aspect_ratio(Keyword.get(opts, :aspect_ratio)),
      resolution: resolution(Keyword.get(opts, :resolution)),
      reference_images: reference_images(opts),
      reference_audios: Enum.map(Keyword.get(opts, :reference_audios, []), &reference_audio/1),
      generate_audio: Keyword.get(opts, :generate_audio),
      storage_options: storage_options(Keyword.get(opts, :storage_options))
    }
  end

  @doc false
  @spec build_extend_request(keyword()) :: Proto.ExtendVideoRequest.t()
  def build_extend_request(opts) do
    check_exclusive!(opts, :video_url, :video_file_id)

    video =
      case opts[:video_file_id] do
        nil -> video_content(Keyword.fetch!(opts, :video_url), nil)
        file_id -> video_content(nil, file_id)
      end

    %Proto.ExtendVideoRequest{
      prompt: Keyword.fetch!(opts, :prompt),
      model: Keyword.get(opts, :model),
      video: video,
      duration: Keyword.get(opts, :duration),
      storage_options: storage_options(Keyword.get(opts, :storage_options))
    }
  end

  defp check_exclusive!(opts, a, b) do
    if opts[a] != nil and opts[b] != nil do
      raise ArgumentError, "only one of #{inspect(a)} or #{inspect(b)} can be set for a request"
    end
  end

  defp image_content(nil, nil), do: nil

  defp image_content(url, nil),
    do: %Proto.ImageUrlContent{source: {:image_url, url}, detail: :DETAIL_AUTO}

  defp image_content(nil, file_id),
    do: %Proto.ImageUrlContent{source: {:file_id, file_id}, detail: :DETAIL_AUTO}

  defp video_content(nil, nil), do: nil
  defp video_content(url, nil), do: %Proto.VideoUrlContent{source: {:url, url}}
  defp video_content(nil, file_id), do: %Proto.VideoUrlContent{source: {:file_id, file_id}}

  # Keyframes are `%{image_url: _, timestamp: _}` or `%{image_file_id: _, timestamp: _}`,
  # like the Python SDK's `UrlKeyframe` / `FileIdKeyframe`.
  defp keyframe(%{timestamp: timestamp} = entry) do
    image =
      case entry do
        %{image_url: url} ->
          image_content(url, nil)

        %{image_file_id: file_id} ->
          image_content(nil, file_id)

        _ ->
          raise ArgumentError,
                "keyframe needs :image_url or :image_file_id, got: #{inspect(entry)}"
      end

    %Proto.VideoKeyframe{image: image, timestamp_s: timestamp / 1}
  end

  defp keyframe(entry),
    do: raise(ArgumentError, "keyframe needs a :timestamp, got: #{inspect(entry)}")

  # File-ID references come first, then URLs — the same order as the Python SDK,
  # so positional references mean the same thing in both.
  defp reference_images(opts) do
    Enum.map(Keyword.get(opts, :reference_image_file_ids, []), &image_content(nil, &1)) ++
      Enum.map(Keyword.get(opts, :reference_image_urls, []), &image_content(&1, nil))
  end

  defp reference_audio(%{voice_id: voice_id}) when is_binary(voice_id) and voice_id != "",
    do: %Proto.AudioUrlContent{source: {:voice_id, voice_id}}

  defp reference_audio(entry),
    do: raise(ArgumentError, "reference audio needs a :voice_id, got: #{inspect(entry)}")

  # Accept the proto enum atom or the Python SDK's string form ("16:9", "1080p").
  @aspect_ratios Map.new(~w(1:1 16:9 9:16 4:3 3:4 3:2 2:3), fn ratio ->
                   {ratio, :"VIDEO_ASPECT_RATIO_#{String.replace(ratio, ":", "_")}"}
                 end)
  @resolutions %{
    "480p" => :VIDEO_RESOLUTION_480P,
    "720p" => :VIDEO_RESOLUTION_720P,
    "1080p" => :VIDEO_RESOLUTION_1080P
  }

  defp aspect_ratio(value) when is_binary(value),
    do: lookup!(@aspect_ratios, value, :aspect_ratio)

  defp aspect_ratio(value), do: value

  defp resolution(value) when is_binary(value), do: lookup!(@resolutions, value, :resolution)
  defp resolution(value), do: value

  defp lookup!(map, value, option) do
    Map.get(map, value) ||
      raise ArgumentError,
            "invalid #{option} #{inspect(value)}, expected one of #{inspect(Map.keys(map))}"
  end

  # `%{filename: "x.mp4", expires_after: 3600, public_url: true | %{expires_after: 60}}`,
  # like the Python SDK's `StorageOptions`. `expires_after` is in seconds.
  defp storage_options(nil), do: nil
  defp storage_options(opts) when is_list(opts), do: storage_options(Map.new(opts))

  defp storage_options(%{filename: filename} = opts) when is_binary(filename) do
    %Proto.StorageOptions{
      filename: filename,
      expires_after: opts[:expires_after],
      public_url: public_url_options(opts[:public_url])
    }
  end

  defp storage_options(other),
    do: raise(ArgumentError, "storage_options needs a :filename, got: #{inspect(other)}")

  defp public_url_options(nil), do: nil
  defp public_url_options(false), do: nil
  defp public_url_options(true), do: %Proto.PublicUrlOptions{}

  defp public_url_options(%{} = opts),
    do: %Proto.PublicUrlOptions{expires_after: opts[:expires_after]}

  defp poll_for_video(client, request_id, timeout, attempts \\ 60)

  defp poll_for_video(_client, _request_id, _timeout, attempts) when attempts <= 0 do
    {:error, :timeout}
  end

  defp poll_for_video(client, request_id, timeout, attempts) do
    req = %Proto.GetDeferredVideoRequest{request_id: request_id}
    metadata = Xai.Client.auth_metadata(client)

    case VideoStub.get_deferred_video(client.channel, req,
           timeout: timeout,
           metadata: metadata
         ) do
      {:ok, %Proto.GetDeferredVideoResponse{status: :DONE, response: resp}} ->
        {:ok, resp}

      {:ok, %Proto.GetDeferredVideoResponse{status: :FAILED}} ->
        {:error, :failed}

      {:ok, _still_running} ->
        Process.sleep(1500)
        poll_for_video(client, request_id, timeout, attempts - 1)

      err ->
        err
    end
  end
end
