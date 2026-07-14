defmodule Xai.ClientTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "raises without api_key" do
      assert_raise ArgumentError, ~r/api_key is required/, fn ->
        Xai.Client.new([])
      end
    end

    test "uses env var if present" do
      System.put_env("XAI_API_KEY", "env-key")

      client = Xai.Client.new(connect: false)

      assert client.api_key == "env-key"
    after
      System.delete_env("XAI_API_KEY")
    end

    test "accepts explicit api_key" do
      client = Xai.Client.new(api_key: "explicit", connect: false)

      assert client.api_key == "explicit"
    end

    test "sets default timeout" do
      client = Xai.Client.new(api_key: "test", connect: false)
      assert client.timeout == :timer.minutes(30)
    end

    test "accepts an explicit :ssl option instead of inferring TLS from the port" do
      client = Xai.Client.new(api_key: "test", connect: false, ssl: false)
      assert client.api_key == "test"
    end
  end
end
