defmodule ExBifrost.Api.OAuthTest do
  use TestCase, async: true

  alias ExBifrost.Api.OAuth
  alias ExBifrost.Connection

  setup do
    bypass = MockServer.setup()
    conn = Connection.new(base_url: MockServer.url(bypass))
    {:ok, bypass: bypass, conn: conn}
  end

  # Add tests for each operation in ExBifrost.Api.OAuth, for example:
  #
  #   test "lists things", %{bypass: bypass, conn: conn} do
  #     MockServer.expect_get(bypass, "/things", 200, %{things: []})
  #     assert {:ok, _response} = OAuth.list_things(conn)
  #   end

  test "module is generated and loaded" do
    assert Code.ensure_loaded?(OAuth)
  end
end
