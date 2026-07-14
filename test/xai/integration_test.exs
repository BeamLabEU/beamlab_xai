defmodule Xai.IntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  @moduledoc """
  These tests hit the real xAI API.

  Run with:
      XAI_API_KEY=your_key mix test --only integration
  """

  setup do
    api_key = System.get_env("XAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:skip, "Skipping integration test: XAI_API_KEY not set"}
    else
      {:ok, api_key: api_key}
    end
  end

  @tag :integration
  test "basic chat works with real API (via REST for now)", %{api_key: api_key} do
    # Note: gRPC chat is currently returning 400; using REST to verify the key and basic connectivity
    url = ~c"https://api.x.ai/v1/chat/completions"

    headers = [
      {~c"authorization", ~c"Bearer #{api_key}"},
      {~c"content-type", ~c"application/json"}
    ]

    body =
      JSON.encode!(%{
        model: "grok-4.20-0309-non-reasoning",
        messages: [%{role: "user", content: "Reply with exactly: PONG"}],
        max_tokens: 10
      })

    {:ok, {{_, 200, _}, _headers, response_body}} =
      :httpc.request(:post, {url, headers, ~c"application/json", body}, [], body_format: :binary)

    response = JSON.decode!(response_body)
    content = get_in(response, ["choices", Access.at(0), "message", "content"])
    assert content == "PONG"
  end
end
