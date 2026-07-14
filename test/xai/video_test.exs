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
      assert request.video.url == "https://example.com/video.mp4"
    end

    test "raises when video_url is missing" do
      assert_raise KeyError, fn ->
        Video.build_extend_request(prompt: "Make it longer")
      end
    end
  end
end
