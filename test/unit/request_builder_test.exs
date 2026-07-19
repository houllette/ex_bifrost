defmodule ExBifrost.RequestBuilderTest do
  use ExUnit.Case, async: true

  import ExBifrost.RequestBuilder

  describe "method/2 and url/2" do
    test "set the request method and url" do
      assert %{method: :get} = method(%{}, :get)
      assert %{url: "/things"} = url(%{}, "/things")
    end
  end

  describe "add_param/4" do
    test "puts a raw body" do
      assert %{body: %{a: 1}} = add_param(%{}, :body, :body, %{a: 1})
    end

    test "adds a named body part as a JSON multipart field" do
      request = add_param(%{}, :body, :metadata, %{a: 1})

      assert %Tesla.Multipart{parts: [part]} = request.body
      assert part.body == ~s({"a":1})
    end

    test "stores headers, replacing duplicates" do
      request =
        %{}
        |> add_param(:headers, :"x-token", "one")
        |> add_param(:headers, :"x-token", "two")

      assert request.headers == [{"x-token", "two"}]
    end

    test "adds a file as a multipart part" do
      path = Path.join(System.tmp_dir!(), "request_builder_#{System.unique_integer([:positive])}")
      File.write!(path, "contents")
      on_exit(fn -> File.rm(path) end)

      assert %{body: %Tesla.Multipart{parts: [_part]}} = add_param(%{}, :file, :file, path)
    end

    test "merges form fields into the body map" do
      request =
        %{}
        |> add_param(:form, :purpose, "batch")
        |> add_param(:form, :name, "test")

      assert request.body == %{purpose: "batch", name: "test"}
    end

    test "form and file parameters compose into one multipart in either order" do
      path = Path.join(System.tmp_dir!(), "request_builder_#{System.unique_integer([:positive])}")
      File.write!(path, "contents")
      on_exit(fn -> File.rm(path) end)

      file_then_form =
        %{}
        |> add_param(:file, :file, path)
        |> add_param(:form, :purpose, "batch")

      form_then_file =
        %{}
        |> add_param(:form, :purpose, "batch")
        |> add_param(:file, :file, path)

      for request <- [file_then_form, form_then_file] do
        assert %Tesla.Multipart{parts: parts} = request.body
        assert Enum.count(parts) == 2
      end
    end

    test "accumulates query parameters" do
      request =
        %{}
        |> add_param(:query, :page, 1)
        |> add_param(:query, :limit, 20)

      assert request.query == [page: 1, limit: 20]
    end
  end

  describe "add_optional_params/3" do
    test "routes known keys to their location and skips unknown keys" do
      definitions = %{page: :query, token: :headers}

      request = add_optional_params(%{}, definitions, page: 2, token: "t", unknown: "x")

      assert request.query == [page: 2]
      assert request.headers == [{"token", "t"}]
      refute Map.has_key?(request, :unknown)
    end
  end

  describe "ensure_body/1" do
    test "replaces a nil body and adds a missing body" do
      assert %{body: ""} = ensure_body(%{body: nil})
      assert %{body: ""} = ensure_body(%{})
      assert %{body: "keep"} = ensure_body(%{body: "keep"})
    end
  end

  describe "evaluate_response/2" do
    test "decodes a matched status into the mapped struct" do
      env = %Tesla.Env{status: 500, body: ~s({"error":{"message":"boom"}})}

      assert {:ok, %ExBifrost.Model.BifrostError{}} =
               evaluate_response({:ok, env}, [{500, ExBifrost.Model.BifrostError}])
    end

    test "decodes a matched status into a plain map with an empty-map mapping" do
      env = %Tesla.Env{status: 200, body: ~s({"a":1})}

      assert {:ok, %{"a" => 1}} = evaluate_response({:ok, env}, [{200, %{}}])
    end

    test "returns the env unchanged when mapped to false" do
      env = %Tesla.Env{status: 200, body: "raw bytes"}

      assert {:ok, ^env} = evaluate_response({:ok, env}, [{200, false}])
    end

    test "falls back to the default mapping" do
      env = %Tesla.Env{status: 418, body: ~s({"a":1})}

      assert {:ok, %{"a" => 1}} = evaluate_response({:ok, env}, [{:default, %{}}, {200, false}])
    end

    test "returns an error tuple when no mapping matches" do
      env = %Tesla.Env{status: 404, body: ""}

      assert {:error, ^env} = evaluate_response({:ok, env}, [{200, %{}}])
    end

    test "passes through transport errors" do
      assert {:error, :nxdomain} = evaluate_response({:error, :nxdomain}, [{200, %{}}])
    end
  end
end
