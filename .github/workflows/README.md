# GitHub Actions Workflows

## Overview

| Workflow | State in template | Purpose |
|---|---|---|
| `template-smoke.yml` | **Active** | End-to-end test of the template itself (setup → generate → compile → test). Removed by `setup.sh` in SDK repos. |
| `test.yml.disabled` | Disabled | Tests, lint, dialyzer on every push/PR |
| `spec-sync.yml.disabled` | Disabled | Weekly check of the upstream spec URL (`.spec-source`); regenerates and opens a PR on changes |
| `conventional-commits.yml.disabled` | Disabled | Validates PR titles against Conventional Commits (feeds release automation) |
| `release.yml.disabled` | Disabled | Manual dispatch: git_ops version bump + changelog + tag, then triggers publish |
| `regenerate-sdk.yml.disabled` | Disabled | Auto-regenerate SDK when the spec changes |
| `publish.yml.disabled` | Disabled | Publish to Hex.pm on version tags |
| `breaking-changes.yml.disabled` | Disabled | Spec-level breaking change detection on PRs |

## Why Are Most Workflows Disabled?

The `.disabled` workflows are designed for SDK projects created from this
template, not for the template itself. Keeping them inactive on the template
repo prevents pointless failing runs.

The one **active** workflow, `template-smoke.yml`, tests the template itself:
it runs the full pipeline against the bundled example spec and fails if any
part of setup, generation, compilation, or testing breaks. It automatically
skips (and is deleted by `setup.sh`) once a repo has been configured as an SDK.

## How to Enable Workflows

Running the setup script enables everything automatically:

```bash
./scripts/setup.sh
```

It renames `*.yml.disabled` → `*.yml` and removes `template-smoke.yml`.

To enable manually instead:

```bash
cd .github/workflows
for file in *.disabled; do mv "$file" "${file%.disabled}"; done
rm template-smoke.yml
```

## Workflow Details

### test.yml

- **Trigger**: push / pull request on `main` and `develop`
- **Jobs**: lint & test on the `.tool-versions` toolchain (Elixir 1.20.2 /
  OTP 29), a compatibility job on the minimum supported toolchain
  (Elixir 1.18 / OTP 27), and dialyzer. Includes `mix deps.unlock
  --check-unused` and `mix hex.audit`.
- **Coverage**: `mix coveralls` enforces the `minimum_coverage` threshold set
  in `coveralls.json` (0 by default; raise it once you have real tests)
- **SBOM**: verifies the committed `bom.cdx.json` matches the current
  dependency set (regenerate with `mix sbom` if it drifts) and uploads it as
  a build artifact

### spec-sync.yml

- **Trigger**: weekly (Monday 9 AM UTC) or manual dispatch
- **Requires**: a `.spec-source` file containing the upstream spec URL
  (written by `setup.sh` when the spec is provided as a URL; GitHub `/blob/`
  URLs are converted to raw URLs)
- Fetches the latest spec; if it differs from the committed
  `openapi-spec.yaml`, regenerates the SDK and opens a PR that includes an
  oasdiff changelog of the API changes
- Skips silently (with a notice) when no `.spec-source` exists
- Same `GITHUB_TOKEN` PR caveat as regenerate-sdk.yml below

### regenerate-sdk.yml

- **Trigger**: changes to `openapi-spec.yaml` on `main`, or manual dispatch
- **Output**: a PR with the regenerated SDK
- **Note**: PRs created with the default `GITHUB_TOKEN` do **not** trigger
  other workflows (including `test.yml`). To get CI on auto-generated PRs,
  create a fine-grained PAT, store it as a secret, and use it as the `token`
  input of the `create-pull-request` step.
- **Note**: the scheduled (cron) trigger is commented out because the spec
  lives in this repo — enable it only if you add a step that fetches the spec
  from a remote source.

### conventional-commits.yml

- **Trigger**: PR opened/edited/synchronized
- Validates the PR title against [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `chore:`, `feat!:` etc.). Use **squash merges** so PR
  titles become the commit messages that release.yml reads.

### release.yml

- **Trigger**: manual dispatch (Actions tab → Release → Run workflow)
- First release: tags the current `@version` from mix.exs. Subsequent
  releases: runs `mix git_ops.release` — the version bump is derived from
  conventional commits since the last tag (`fix:` → patch, `feat:` → minor,
  `!`/`BREAKING CHANGE` → major), `@version` and CHANGELOG.md are updated,
  and the release commit is tagged
- Requires the `<!-- changelog -->` marker in CHANGELOG.md (present in the
  fresh changelog written by `scripts/setup.sh`)
- After pushing the tag it dispatches publish.yml explicitly (tag pushes made
  with `GITHUB_TOKEN` don't trigger workflows on their own)

### publish.yml

- **Trigger**: version tags (`v*.*.*`) or manual dispatch
- **Requirements**: `HEX_API_KEY` secret (get it from `mix hex.user auth`)
- Verifies the tag matches `@version` in `mix.exs`, runs tests, publishes to
  Hex.pm, and creates a GitHub release with the CycloneDX SBOM
  (`bom.cdx.json`) attached

### breaking-changes.yml

- **Trigger**: PRs modifying `openapi-spec.yaml` or `lib/**`
- Uses [oasdiff](https://github.com/oasdiff/oasdiff) to detect breaking
  changes between the base and PR versions of the spec; fails the check if
  any are found and comments on the PR
- Also posts an **informational** note when public `def` lines change in
  `lib/` (this heuristic cannot distinguish removals from modifications, so
  it never fails the build)

## Configuration Required

1. **Repository secrets** (Settings → Secrets → Actions):
   - `HEX_API_KEY` — required by publish.yml
2. **Branch protection** (recommended): require status checks before merging

## Troubleshooting

- **Workflows not running?** Check that files have the `.yml` extension, are
  pushed, and Actions are enabled in repo settings.
- **Publish failing?** Verify `HEX_API_KEY` is set and `@version` in `mix.exs`
  matches the tag.
- **Coverage gate failing?** Adjust `minimum_coverage` in `coveralls.json` or
  add tests.
