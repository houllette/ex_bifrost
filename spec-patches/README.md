# Spec patches

Durable local fixes for defects in the upstream OpenAPI spec.

Real-world specs ship problems — duplicate `operationId`s, a parameter
declared in both query and body, invalid examples. Editing
`openapi-spec.yaml` by hand is not durable: the weekly spec-sync workflow
re-downloads the upstream spec and silently reintroduces every defect.
Patches placed here are applied automatically:

- after the spec is downloaded (setup and the spec-sync workflow), and
- before every regeneration (`./scripts/regenerate.sh`),

so your fixes survive spec updates and stay reviewable in git.

## Contract

- A patch is any **executable** file in this directory (non-executable files
  like this README are ignored).
- Patches run in **lexicographic order** — prefix them with a number:
  `10-dedupe-operation-ids.sh`, `20-drop-duplicate-param.sh`.
- Each patch is invoked with one argument: the path to the spec file. It
  should edit the file in place (yq, jq, sed, python — anything available in
  CI).
- Patches **must be idempotent**: they run on every regeneration, including
  on a spec they already patched.
- A patch that exits non-zero **fails the pipeline** with a clear message.
  If upstream fixed the defect a patch works around, delete the patch.

## Example

```bash
#!/usr/bin/env bash
# 10-rename-duplicate-operation-id.sh — upstream declares listItems twice
set -euo pipefail
spec="$1"

# Idempotent: only rewrite the second occurrence if it is still present in
# the offending path group.
python3 - "$spec" <<'PY'
import sys, re
path = sys.argv[1]
text = open(path).read()
patched = text.replace(
    "operationId: listItems\n      tags:\n        - archive",
    "operationId: listArchivedItems\n      tags:\n        - archive",
)
open(path, "w").write(patched)
PY
```

Spec-sync PRs will fail loudly (rather than silently regressing) when a
patch no longer applies cleanly.
