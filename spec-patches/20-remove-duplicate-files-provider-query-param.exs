#!/usr/bin/env elixir
# Upstream defect: POST /v1/files declares `provider` both as a query
# parameter and a multipart form field, generating a duplicate-map-key
# compiler warning (fatal under --warnings-as-errors). Drop the redundant
# query parameter; the form field and x-model-provider header remain.
# Upstream report target: maximhq/bifrost — delete this patch once fixed.
Code.require_file(Path.join(__DIR__, "spec_json.exs"))

[spec_path] = System.argv()
spec = SpecJson.read!(spec_path)

if SpecJson.get_in(spec, ["paths", "/v1/files", "post"]) == nil do
  IO.puts(:stderr, "upstream removed POST /v1/files — review this patch")
  System.halt(1)
end

spec =
  SpecJson.update_in!(spec, ["paths", "/v1/files", "post"], fn op ->
    kept =
      op
      |> SpecJson.get_in(["parameters"])
      |> List.wrap()
      |> Enum.reject(fn param ->
        SpecJson.get_in(param, ["name"]) == "provider" and SpecJson.get_in(param, ["in"]) == "query"
      end)

    if kept == [] do
      SpecJson.delete(op, "parameters")
    else
      SpecJson.put(op, "parameters", kept)
    end
  end)

SpecJson.write!(spec_path, spec)
