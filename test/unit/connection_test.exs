defmodule ExBifrost.ConnectionTest do
  use ExUnit.Case, async: true

  alias ExBifrost.Connection

  describe "new/1, middleware/1, and adapter/0" do
    test "builds a Tesla client with defaults" do
      assert %Tesla.Client{} = Connection.new()
    end

    test "includes basic auth middleware only when credentials are given" do
      with_auth = Connection.middleware(username: "user", password: "secret")
      without_auth = Connection.middleware()

      assert Enum.any?(with_auth, &match?({Tesla.Middleware.BasicAuth, _opts}, &1))
      refute Enum.any?(without_auth, &match?({Tesla.Middleware.BasicAuth, _opts}, &1))
    end

    test "includes bearer auth and appends custom middleware" do
      middleware =
        Connection.middleware(bearer_token: "token", middleware: [Tesla.Middleware.Logger])

      assert {Tesla.Middleware.BearerAuth, token: "token"} in middleware
      assert Tesla.Middleware.Logger in middleware
    end

    test "retry middleware is on by default and removable with retry: false" do
      assert Enum.any?(Connection.middleware(), &match?({Tesla.Middleware.Retry, _opts}, &1))

      refute Enum.any?(
               Connection.middleware(retry: false),
               &match?({Tesla.Middleware.Retry, _opts}, &1)
             )
    end

    test "uses the configured base_url" do
      assert {Tesla.Middleware.BaseUrl, "http://example.test"} in Connection.middleware(base_url: "http://example.test")
    end

    test "adapter defaults to the pooled Finch instance" do
      assert {Tesla.Adapter.Finch, name: ExBifrost.Finch} = Connection.adapter()
    end
  end

  describe "retry behavior" do
    setup do
      bypass = Bypass.open()
      {:ok, counter} = Agent.start_link(fn -> 0 end)
      {:ok, bypass: bypass, counter: counter}
    end

    test "retries idempotent requests on retriable statuses", %{bypass: bypass, counter: counter} do
      Bypass.expect(bypass, "GET", "/thing", fn conn ->
        attempt = Agent.get_and_update(counter, &{&1, &1 + 1})
        status = if attempt == 0, do: 503, else: 200
        Plug.Conn.resp(conn, status, "{}")
      end)

      client = client(bypass, retry: [delay: 1, max_retries: 2])

      assert {:ok, %Tesla.Env{status: 200}} =
               Connection.request(client, method: :get, url: "/thing")

      assert Agent.get(counter, & &1) == 2
    end

    test "never retries POST requests", %{bypass: bypass, counter: counter} do
      Bypass.expect(bypass, "POST", "/thing", fn conn ->
        Agent.update(counter, &(&1 + 1))
        Plug.Conn.resp(conn, 503, "{}")
      end)

      client = client(bypass, retry: [delay: 1, max_retries: 3])

      assert {:ok, %Tesla.Env{status: 503}} =
               Connection.request(client, method: :post, url: "/thing", body: "{}")

      assert Agent.get(counter, & &1) == 1
    end

    test "retries transport errors for idempotent methods and gives up", %{bypass: bypass} do
      Bypass.down(bypass)
      client = client(bypass, retry: [delay: 1, max_retries: 1])

      assert {:error, _reason} = Connection.request(client, method: :get, url: "/thing")
    end

    test "does not retry transport errors for POST", %{bypass: bypass} do
      Bypass.down(bypass)
      client = client(bypass, retry: [delay: 1, max_retries: 1])

      assert {:error, _reason} =
               Connection.request(client, method: :post, url: "/thing", body: "{}")
    end

    defp client(bypass, opts) do
      Connection.new([base_url: "http://localhost:#{bypass.port}"] ++ opts)
    end
  end
end
