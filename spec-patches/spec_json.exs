# Shared helper for spec patches (not executable — not itself a patch).
# Load with: Code.require_file(Path.join(__DIR__, "spec_json.exs"))
defmodule SpecJson do
  @moduledoc """
  Order-preserving, deterministic JSON I/O for OpenAPI spec patches.

  Objects decode to `{:obj, [{key, value}, ...]}` (via OTP's `:json` custom
  decoders) instead of maps, so re-encoding preserves the upstream spec's
  key order exactly — key order feeds openapi-generator output (struct field
  order and more), and byte-stable output is what lets the spec-sync
  workflow compare the patched download against the committed spec with
  `cmp`. Encoding is pretty-printed with 2-space indentation; repeated runs
  produce identical bytes on any OTP version.
  """

  def read!(path) do
    {spec, :ok, rest} =
      :json.decode(File.read!(path), :ok, %{
        object_start: fn _acc -> [] end,
        object_push: fn key, value, acc -> [{key, value} | acc] end,
        object_finish: fn acc, old_acc -> {{:obj, Enum.reverse(acc)}, old_acc} end,
        # JSON null must decode to nil: JSON.encode!(nil) emits null, while
        # the default :null atom would re-encode as the *string* "null"
        null: nil
      })

    "" = String.trim(rest)
    spec
  end

  def write!(path, spec), do: File.write!(path, [encode(spec, 0), "\n"])

  @doc "Fetches the value at a key path. Returns nil when absent."
  def get_in(spec, []), do: spec

  def get_in({:obj, kvs}, [key | rest]) do
    case List.keyfind(kvs, key, 0) do
      {^key, value} -> __MODULE__.get_in(value, rest)
      nil -> nil
    end
  end

  def get_in(_other, _keys), do: nil

  @doc """
  Replaces the value at an existing key path with `fun.(value)`, preserving
  object key order. Raises if the path does not exist.
  """
  def update_in!(spec, [], fun), do: fun.(spec)

  def update_in!({:obj, kvs}, [key | rest], fun) do
    case List.keyfind(kvs, key, 0) do
      {^key, value} ->
        {:obj, List.keyreplace(kvs, key, 0, {key, update_in!(value, rest, fun)})}

      nil ->
        raise "key #{inspect(key)} not found"
    end
  end

  @doc "Removes a key from an object, preserving the order of the rest."
  def delete({:obj, kvs}, key), do: {:obj, List.keydelete(kvs, key, 0)}

  @doc "Replaces (or appends) a key's value in an object, preserving order."
  def put({:obj, kvs}, key, value) do
    if List.keymember?(kvs, key, 0) do
      {:obj, List.keyreplace(kvs, key, 0, {key, value})}
    else
      {:obj, kvs ++ [{key, value}]}
    end
  end

  defp encode({:obj, []}, _indent), do: "{}"

  defp encode({:obj, kvs}, indent) do
    inner = String.duplicate("  ", indent + 1)

    entries =
      Enum.map(kvs, fn {key, value} ->
        [inner, JSON.encode!(key), ": ", encode(value, indent + 1)]
      end)

    ["{\n", Enum.intersperse(entries, ",\n"), "\n", String.duplicate("  ", indent), "}"]
  end

  defp encode([], _indent), do: "[]"

  defp encode(list, indent) when is_list(list) do
    inner = String.duplicate("  ", indent + 1)
    entries = Enum.map(list, fn value -> [inner, encode(value, indent + 1)] end)

    ["[\n", Enum.intersperse(entries, ",\n"), "\n", String.duplicate("  ", indent), "]"]
  end

  defp encode(scalar, _indent), do: JSON.encode!(scalar)
end
