defmodule ExBifrost.DeserializerTest do
  use ExUnit.Case, async: true

  alias ExBifrost.Deserializer

  defmodule Inner do
    defstruct [:name]

    def decode(model), do: model
  end

  describe "json_decode/1 and json_decode/2" do
    test "decodes valid JSON" do
      assert {:ok, %{"a" => 1}} = Deserializer.json_decode(~s({"a":1}))
    end

    test "returns an error for invalid JSON" do
      assert {:error, _reason} = Deserializer.json_decode("{not json")
    end

    test "decodes into a struct, ignoring unknown fields" do
      assert {:ok, %Inner{name: "x"}} = Deserializer.json_decode(~s({"name":"x","extra":1}), Inner)
    end

    test "decodes a JSON array into a list of structs" do
      assert {:ok, [%Inner{name: "x"}, %Inner{name: "y"}]} =
               Deserializer.json_decode(~s([{"name":"x"},{"name":"y"}]), Inner)
    end

    test "propagates decode errors with a module" do
      assert {:error, _reason} = Deserializer.json_decode("{not json", Inner)
    end
  end

  describe "deserialize/4" do
    test ":struct converts a nested map and leaves nil alone" do
      model = %{child: %{"name" => "x"}, empty: nil}

      assert %{child: %Inner{name: "x"}} = Deserializer.deserialize(model, :child, :struct, Inner)
      assert %{empty: nil} = Deserializer.deserialize(model, :empty, :struct, Inner)
    end

    test ":list converts each element and leaves nil alone" do
      model = %{children: [%{"name" => "x"}], empty: nil}

      assert %{children: [%Inner{name: "x"}]} =
               Deserializer.deserialize(model, :children, :list, Inner)

      assert %{empty: nil} = Deserializer.deserialize(model, :empty, :list, Inner)
    end

    test ":map converts each value and leaves nil alone" do
      model = %{by_id: %{"a" => %{"name" => "x"}}, empty: nil}

      assert %{by_id: %{"a" => %Inner{name: "x"}}} =
               Deserializer.deserialize(model, :by_id, :map, Inner)

      assert %{empty: nil} = Deserializer.deserialize(model, :empty, :map, Inner)
    end

    test ":date parses ISO 8601 dates and keeps invalid or absent values" do
      assert %{on: ~D[2026-07-19]} = Deserializer.deserialize(%{on: "2026-07-19"}, :on, :date, nil)
      assert %{on: "not a date"} = Deserializer.deserialize(%{on: "not a date"}, :on, :date, nil)
      assert %{on: 5} = Deserializer.deserialize(%{on: 5}, :on, :date, nil)
    end

    test ":datetime parses ISO 8601 datetimes and keeps invalid or absent values" do
      assert %{at: ~U[2026-07-19 12:00:00Z]} =
               Deserializer.deserialize(%{at: "2026-07-19T12:00:00Z"}, :at, :datetime, nil)

      assert %{at: "nope"} = Deserializer.deserialize(%{at: "nope"}, :at, :datetime, nil)
      assert %{at: 5} = Deserializer.deserialize(%{at: 5}, :at, :datetime, nil)
    end

    test ":struct passes scalar values to the module decode" do
      assert %{child: "raw"} = Deserializer.deserialize(%{child: "raw"}, :child, :struct, Inner)
    end
  end
end
