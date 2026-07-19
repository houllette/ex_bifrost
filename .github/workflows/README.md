# GitHub Actions Workflows

## Overview

| Workflow | Purpose |
|---|---|
| `test.yml` | Tests, lint, dialyzer, coverage, SBOM drift check on every push/PR |
| `spec-sync.yml` | Weekly check of the upstream spec URL (`.spec-source`); regenerates and opens a PR on changes |
| `conventional-commits.yml` | Validates PR titles against Conventional Commits (feeds release automation) |
| `release.yml` | Manual dispatch: git_ops version bump + changelog + tag, then triggers publish |
| `regenerate-sdk.yml` | Auto-regenerate SDK when the spec changes |
| `publish.yml` | Publish to Hex.pm on version tags |
| `breaking-changes.yml` | Spec-level breaking change detection on PRs |

## Workflow Details

### test.yml

- **Trigger**: push / pull request on `main` and `develop`
- **Jobs**: lint & test on the `.tool-versions` toolchain (Elixir 1.20.2 /
  OTP 29), a compatibility job on the minimum supported toolchain
  (Elixir 1.18 / OTP 27), and dialyzer. Includes `mix deps.unlock
  --check-unused` and `mix hex.audit`.
- **Coverage**: `mix coveralls` enforces the `minimum_coverage` threshold set
  in `coveralls.json` (currently 90; raise it as hand-written tests grow)
- **SBOM**: verifies the committed `bom.cdx.json` matches the current
  dependency set. Only fields derived from `mix.exs`/`mix.lock` are compared
  (hex components, purls, versions, hashes, dependency graph) — hex.pm
  enrichment and OTP system components vary by environment and are excluded.
  On drift it prints a normalized diff; regenerate with `mix sbom` (the
  pre-commit hook does this automatically when mix.exs/mix.lock change).

### spec-sync.yml

- **Trigger**: weekly (Monday 9 AM UTC) or manual dispatch
- **Requires**: the `.spec-source` file containing the upstream spec URL
- Fetches the latest spec; if it differs from the committed
  `openapi-spec.yaml`, regenerates the SDK and opens a PR that includes an
  oasdiff changelog of the API changes
- **Caution**: local patches to the spec (see "Known upstream spec issues"
  in `AGENTS.md`) are overwritten by a sync — re-apply them when reviewing
  sync PRs
- Same `GITHUB_TOKEN` PR caveat as regenerate-sdk.yml below

### regenerate-sdk.yml

- **Trigger**: changes to `openapi-spec.yaml` on `main`, or manual dispatch
- **Output**: a PR with the regenerated SDK
- **Note**: PRs created with the default `GITHUB_TOKEN` do **not** trigger
  other workflows (including `test.yml`). To get CI on auto-generated PRs,
  create a fine-grained PAT, store it as a secret, and use it as the `token`
  input of the `create-pull-request` step.

### conventional-commits.yml

- **Trigger**: PR opened/edited/synchronized
- Validates the PR title against [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `chore:`, `feat!:` etc.). Use **squash merges** so PR
  titles become the commit messages that release automation reads.

### release.yml

- **Trigger**: manual dispatch (Actions tab → Release → Run workflow)
- Runs `mix git_ops.release` — the version bump is derived from conventional
  commits since the last tag (`fix:` → patch, `feat:` → minor,
  `!`/`BREAKING CHANGE` → major), `@version` and CHANGELOG.md are updated,
  and the release commit is tagged. Releases can also be cut locally with
  `mix git_ops.release` + `git push --follow-tags`.
- Requires the `<!-- changelog -->` marker in CHANGELOG.md (git_ops
  maintains the file)
- After pushing the tag it dispatches publish.yml explicitly (tag pushes made
  with `GITHUB_TOKEN` don't trigger workflows on their own)

### publish.yml

- **Trigger**: version tags (`v*.*.*`) or manual dispatch
- **Requirements**: `HEX_API_KEY` secret — generate a key with `api:write`
  permission at hex.pm → Dashboard → Keys (Hex ≥ 2.5 removed CLI key
  generation for user accounts)
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
   - `HEX_API_KEY` — required by publish.yml (see above for how to create it)
2. **Branch protection** (recommended): require status checks before merging

## Troubleshooting

- **Workflows not running?** Check that files have the `.yml` extension, are
  pushed, and Actions are enabled in repo settings.
- **Publish failing?** Verify `HEX_API_KEY` is set and `@version` in `mix.exs`
  matches the tag.
- **Coverage gate failing?** Add tests (preferred) or adjust
  `minimum_coverage` in `coveralls.json`.
- **SBOM check failing?** Enable the versioned hooks
  (`git config core.hooksPath .githooks`) or run `mix sbom` and commit the
  result; the CI log prints the exact diff.
