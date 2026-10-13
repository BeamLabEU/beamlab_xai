defmodule Xai.VideoTest do
  use ExUnit.Case, async: true

  alias Xai.Video

  describe "build_generate_request/1" do
    test "sets prompt, model, and duration" do
      request =
        Video.build_generate_request(
          prompt: "A cat on a skateboard",
          model: "grok-imagine-video",
          duration: 5
        )

      assert request.prompt == "A cat on a skateboard"
      assert request.model == "grok-imagine-video"
      assert request.duration == 5
    end

    test "defaults model to grok-imagine-video" do
      request = Video.build_generate_request(prompt: "A cat on a skateboard")

      assert request.model == "grok-imagine-video"
    end

    test "passes aspect_ratio and resolution through instead of dropping them" do
      request =
        Video.build_generate_request(
          prompt: "A cat on a skateboard",
          aspect_ratio: :VIDEO_ASPECT_RATIO_16_9,
          resolution: :VIDEO_RESOLUTION_720P
        )

      assert request.aspect_ratio == :VIDEO_ASPECT_RATIO_16_9
      assert request.resolution == :VIDEO_RESOLUTION_720P
    end

    test "raises when prompt is missing" do
      assert_raise KeyError, fn -> Video.build_generate_request([]) end
    end

    test "accepts Python SDK string forms for aspect_ratio and resolution" do
      request =
        Video.build_generate_request(prompt: "p", aspect_ratio: "9:16", resolution: "1080p")

      assert request.aspect_ratio == :VIDEO_ASPECT_RATIO_9_16
      assert request.resolution == :VIDEO_RESOLUTION_1080P
    end

    test "rejects unknown aspect_ratio / resolution strings" do
      assert_raise ArgumentError, ~r/invalid aspect_ratio/, fn ->
        Video.build_generate_request(prompt: "p", aspect_ratio: "5:7")
      end

      assert_raise ArgumentError, ~r/invalid resolution/, fn ->
        Video.build_generate_request(prompt: "p", resolution: "4k")
      end
    end

    test "builds first frame, last frame and source video from URLs or file ids" do
      request =
        Video.build_generate_request(
          prompt: "p",
          image_url: "https://e.com/a.png",
          last_frame_file_id: "file_last",
          video_file_id: "file_vid"
        )

      assert request.image.source == {:image_url, "https://e.com/a.png"}
      assert request.image.detail == :DETAIL_AUTO
      assert request.last_frame.source == {:file_id, "file_last"}
      assert request.video.source == {:file_id, "file_vid"}
    end

    test "leaves unset media fields nil" do
      request = Video.build_generate_request(prompt: "p")

      assert request.image == nil
      assert request.last_frame == nil
      assert request.video == nil
      assert request.keyframes == []
      assert request.reference_images == []
      assert request.reference_audios == []
      assert request.generate_audio == nil
      assert request.storage_options == nil
    end

    test "raises when both a URL and a file id are given" do
      for {a, b} <- [
            {:image_url, :image_file_id},
            {:video_url, :video_file_id},
            {:last_frame_url, :last_frame_file_id}
          ] do
        assert_raise ArgumentError, ~r/only one of/, fn ->
          Video.build_generate_request([{:prompt, "p"}, {a, "x"}, {b, "y"}])
        end
      end
    end

    test "builds keyframes from URLs and file ids" do
      request =
        Video.build_generate_request(
          prompt: "p",
          keyframes: [
            %{image_url: "https://e.com/k1.png", timestamp: 2.5},
            %{image_file_id: "file_k2", timestamp: 4}
          ]
        )

      assert [k1, k2] = request.keyframes
      assert k1.image.source == {:image_url, "https://e.com/k1.png"}
      assert k1.timestamp_s == 2.5
      assert k2.image.source == {:file_id, "file_k2"}
      assert k2.timestamp_s == 4.0
    end

    test "rejects malformed keyframes" do
      assert_raise ArgumentError, ~r/:timestamp/, fn ->
        Video.build_generate_request(prompt: "p", keyframes: [%{image_url: "u"}])
      end

      assert_raise ArgumentError, ~r/:image_url or :image_file_id/, fn ->
        Video.build_generate_request(prompt: "p", keyframes: [%{timestamp: 1}])
      end
    end

    test "puts file-id references before URL references" do
      request =
        Video.build_generate_request(
          prompt: "p",
          reference_image_urls: ["https://e.com/1.png"],
          reference_image_file_ids: ["file_1", "file_2"]
        )

      assert Enum.map(request.reference_images, & &1.source) == [
               {:file_id, "file_1"},
               {:file_id, "file_2"},
               {:image_url, "https://e.com/1.png"}
             ]
    end

    test "builds reference audios and generate_audio" do
      request =
        Video.build_generate_request(
          prompt: "p",
          reference_audios: [%{voice_id: "ara"}],
          generate_audio: false
        )

      assert [%{source: {:voice_id, "ara"}}] = request.reference_audios
      assert request.generate_audio == false

      assert_raise ArgumentError, ~r/:voice_id/, fn ->
        Video.build_generate_request(prompt: "p", reference_audios: [%{voice_id: ""}])
      end
    end

    test "builds storage options" do
      request =
        Video.build_generate_request(
          prompt: "p",
          storage_options: %{filename: "clip.mp4", expires_after: 3600, public_url: true}
        )

      assert request.storage_options.filename == "clip.mp4"
      assert request.storage_options.expires_after == 3600
      assert request.storage_options.public_url == %XaiApi.PublicUrlOptions{}

      request =
        Video.build_generate_request(
          prompt: "p",
          storage_options: [filename: "c.mp4", public_url: %{expires_after: 60}]
        )

      assert request.storage_options.expires_after == nil
      assert request.storage_options.public_url.expires_after == 60

      request = Video.build_generate_request(prompt: "p", storage_options: %{filename: "c.mp4"})
      assert request.storage_options.public_url == nil
    end

    test "storage options require a filename" do
      assert_raise ArgumentError, ~r/:filename/, fn ->
        Video.build_generate_request(prompt: "p", storage_options: %{expires_after: 1})
      end
    end

    test "requests with new fields round-trip through protobuf encoding" do
      request =
        Video.build_generate_request(
          prompt: "p",
          image_url: "https://e.com/a.png",
          last_frame_file_id: "f",
          keyframes: [%{image_url: "u", timestamp: 1}],
          reference_audios: [%{voice_id: "ara"}],
          generate_audio: true,
          resolution: "1080p",
          storage_options: %{filename: "c.mp4", public_url: true}
        )

      assert request ==
               request
               |> XaiApi.GenerateVideoRequest.encode()
               |> XaiApi.GenerateVideoRequest.decode()
    end
  end

  describe "build_extend_request/1" do
    test "sets prompt, model, and video url" do
      request =
        Video.build_extend_request(
          prompt: "Make it longer",
          model: "grok-imagine-video",
          video_url: "https://example.com/video.mp4"
        )

      assert request.prompt == "Make it longer"
      assert request.model == "grok-imagine-video"
      assert request.video.source == {:url, "https://example.com/video.mp4"}
    end

    test "accepts a file id instead of a URL" do
      request = Video.build_extend_request(prompt: "p", video_file_id: "file_1")

      assert request.video.source == {:file_id, "file_1"}
    end

    test "passes duration and storage options" do
      request =
        Video.build_extend_request(
          prompt: "p",
          video_url: "https://e.com/v.mp4",
          duration: 6,
          storage_options: %{filename: "ext.mp4"}
        )

      assert request.duration == 6
      assert request.storage_options.filename == "ext.mp4"
    end

    test "raises when both video_url and video_file_id are given" do
      assert_raise ArgumentError, ~r/only one of/, fn ->
        Video.build_extend_request(prompt: "p", video_url: "u", video_file_id: "f")
      end
    end

    test "raises when video_url is missing" do
      assert_raise KeyError, fn ->
        Video.build_extend_request(prompt: "Make it longer")
      end
    end
  end
end
