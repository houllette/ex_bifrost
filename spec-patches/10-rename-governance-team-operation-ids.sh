#!/usr/bin/env bash
# Upstream defect: /api/governance/teams* operations reuse the operationIds
# of /api/teams* (listTeams, createTeam, ...), which is a hard validation
# error for openapi-generator. Rename the governance variants.
# Upstream report target: maximhq/bifrost — delete this patch once fixed.
set -euo pipefail

python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as f:
    spec = json.load(f)

RENAMES = {
    ("get", "/api/governance/teams"): ("listTeams", "listGovernanceTeams"),
    ("post", "/api/governance/teams"): ("createTeam", "createGovernanceTeam"),
    ("get", "/api/governance/teams/{team_id}"): ("getTeam", "getGovernanceTeam"),
    ("put", "/api/governance/teams/{team_id}"): ("updateTeam", "updateGovernanceTeam"),
    ("delete", "/api/governance/teams/{team_id}"): ("deleteTeam", "deleteGovernanceTeam"),
}

for (method, api_path), (duplicate_id, new_id) in RENAMES.items():
    op = spec.get("paths", {}).get(api_path, {}).get(method)
    if op is None:
        sys.exit(f"upstream removed {method.upper()} {api_path} — review this patch")
    current = op.get("operationId")
    if current == new_id:
        continue  # already patched (idempotent re-run)
    if current != duplicate_id:
        sys.exit(
            f"{method.upper()} {api_path} has operationId {current!r} (expected the "
            f"duplicate {duplicate_id!r}) — upstream may have fixed this; review/delete this patch"
        )
    op["operationId"] = new_id

with open(path, "w") as f:
    json.dump(spec, f, indent=2)
    f.write("\n")
PY
