defmodule Xai.VideoTest do
  use ExUnit.Case, async: true

  describe "request building" do
    test "module loads and basic API is present" do
      # Placeholder - expand with actual request struct tests or mock the Stub.
      Code.ensure_loaded!(Xai.Video)
      assert function_exported?(Xai.Video, :generate, 2)
      assert function_exported?(Xai.Video, :extend, 2)
    end
  end
end
