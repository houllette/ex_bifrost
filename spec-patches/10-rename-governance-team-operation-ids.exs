#!/usr/bin/env elixir
# Upstream defect: /api/governance/teams* operations reuse the operationIds
# of /api/teams* (listTeams, createTeam, ...), which is a hard validation
# error for openapi-generator. Rename the governance variants.
# Upstream report target: maximhq/bifrost — delete this patch once fixed.
Code.require_file(Path.join(__DIR__, "spec_json.exs"))

[spec_path] = System.argv()
spec = SpecJson.read!(spec_path)

renames = [
  {"get", "/api/governance/teams", "listTeams", "listGovernanceTeams"},
  {"post", "/api/governance/teams", "createTeam", "createGovernanceTeam"},
  {"get", "/api/governance/teams/{team_id}", "getTeam", "getGovernanceTeam"},
  {"put", "/api/governance/teams/{team_id}", "updateTeam", "updateGovernanceTeam"},
  {"delete", "/api/governance/teams/{team_id}", "deleteTeam", "deleteGovernanceTeam"}
]

spec =
  Enum.reduce(renames, spec, fn {method, api_path, duplicate_id, new_id}, spec ->
    case SpecJson.get_in(spec, ["paths", api_path, method, "operationId"]) do
      nil ->
        IO.puts(:stderr, "upstream removed #{String.upcase(method)} #{api_path} — review this patch")
        System.halt(1)

      ^new_id ->
        # already patched (idempotent re-run)
        spec

      ^duplicate_id ->
        SpecJson.update_in!(spec, ["paths", api_path, method], &SpecJson.put(&1, "operationId", new_id))

      other ->
        IO.puts(
          :stderr,
          "#{String.upcase(method)} #{api_path} has operationId #{inspect(other)} (expected the " <>
            "duplicate #{inspect(duplicate_id)}) — upstream may have fixed this; review/delete this patch"
        )

        System.halt(1)
    end
  end)

SpecJson.write!(spec_path, spec)
