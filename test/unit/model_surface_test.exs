defmodule ExBifrost.ModelSurfaceTest do
  @moduledoc """
  Smoke coverage of every generated model module.

  Each `ExBifrost.Model.*` module must build its struct (when it defines
  one) and run its `decode/1` pipeline without raising. This guards the
  generated deserialization chains across regenerations of the SDK.
  """

  use ExUnit.Case, async: true

  test "every model module builds a struct and decodes" do
    failures =
      Enum.reduce(model_modules(), [], fn module, acc ->
        {:module, ^module} = Code.ensure_loaded(module)

        input =
          if function_exported?(module, :__struct__, 1) do
            struct(module)
          else
            %{}
          end

        try do
          module.decode(input)
          acc
        rescue
          error -> [{module, error} | acc]
        end
      end)

    assert failures == []
  end

  test "the generated model surface is present" do
    assert length(model_modules()) > 500
  end

  defp model_modules do
    {:ok, modules} = :application.get_key(:ex_bifrost, :modules)

    Enum.filter(modules, fn module ->
      module |> Atom.to_string() |> String.starts_with?("Elixir.ExBifrost.Model.")
    end)
  end
end
