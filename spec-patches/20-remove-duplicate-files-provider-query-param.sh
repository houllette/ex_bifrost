#!/usr/bin/env bash
# Upstream defect: POST /v1/files declares `provider` both as a query
# parameter and a multipart form field, generating a duplicate-map-key
# compiler warning (fatal under --warnings-as-errors). Drop the redundant
# query parameter; the form field and x-model-provider header remain.
# Upstream report target: maximhq/bifrost — delete this patch once fixed.
set -euo pipefail

python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as f:
    spec = json.load(f)

op = spec.get("paths", {}).get("/v1/files", {}).get("post")
if op is None:
    sys.exit("upstream removed POST /v1/files — review this patch")

params = op.get("parameters", [])
kept = [p for p in params if not (p.get("name") == "provider" and p.get("in") == "query")]
if kept:
    op["parameters"] = kept
else:
    op.pop("parameters", None)

with open(path, "w") as f:
    json.dump(spec, f, indent=2)
    f.write("\n")
PY
