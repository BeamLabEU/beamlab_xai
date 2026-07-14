defmodule Xai.ChatTest do
  use ExUnit.Case, async: true

  alias Xai.Chat

  describe "message helpers" do
    test "user/1 creates a user message with text content" do
      msg = Chat.user("Hello")

      assert %XaiApi.Message{role: :ROLE_USER} = msg
      assert [%XaiApi.Content{content: {:text, "Hello"}}] = msg.content
    end

    test "system/1 creates a system message" do
      msg = Chat.system("You are helpful.")

      assert %XaiApi.Message{role: :ROLE_SYSTEM} = msg
      assert [%XaiApi.Content{content: {:text, "You are helpful."}}] = msg.content
    end
  end

  describe "session" do
    test "create/2 + append/2 builds messages" do
      client = %Xai.Client{api_key: "test"}

      session =
        Chat.create(client, model: "grok-4.5")
        |> Chat.append(Chat.system("Be concise."))
        |> Chat.append("What is 2+2?")

      assert session.model == "grok-4.5"
      assert length(session.messages) == 2
    end
  end
end
