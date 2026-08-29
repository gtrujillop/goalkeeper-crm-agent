defmodule StoreCRM.AI.FakeProviderTest do
  use ExUnit.Case, async: true

  alias StoreCRM.AI.FakeProvider

  test "returns a deterministic response without external API access" do
    request = %{
      instructions: "Help the customer.",
      messages: [%{role: :user, content: "I need gloves for artificial turf"}]
    }

    assert {:ok, response} = FakeProvider.respond(request)
    assert response.message =~ "I need gloves for artificial turf"
    assert response.tool_calls == []
    assert response.provider_metadata.provider == :fake
  end
end
