defmodule ExBifrost.Api.ModelsTest do
  use TestCase, async: true

  alias ExBifrost.Api.Models
  alias ExBifrost.Connection

  setup do
    bypass = MockServer.setup()
    conn = Connection.new(base_url: MockServer.url(bypass))
    {:ok, bypass: bypass, conn: conn}
  end

  # Add tests for each operation in ExBifrost.Api.Models, for example:
  #
  #   test "lists things", %{bypass: bypass, conn: conn} do
  #     MockServer.expect_get(bypass, "/things", 200, %{things: []})
  #     assert {:ok, _response} = Models.list_things(conn)
  #   end

  test "module is generated and loaded" do
    assert Code.ensure_loaded?(Models)
  end
end
