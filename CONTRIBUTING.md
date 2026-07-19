# Contributing to ex_bifrost

Thank you for considering contributing! `ex_bifrost` is the Elixir SDK for
[Bifrost](https://github.com/maximhq/bifrost), generated from Bifrost's
OpenAPI specification. This document covers how to report issues, propose
changes, and navigate the generated-code workflow.

## Code of Conduct

Be respectful and constructive in all interactions.

## Reporting Bugs

When reporting bugs, please include:

1. **Description**: Clear description of the issue
2. **Steps to Reproduce**: Detailed steps, ideally a minimal code sample
3. **Expected Behavior**: What you expected to happen
4. **Actual Behavior**: What actually happened
5. **Environment**:
   - `ex_bifrost` version
   - Elixir version (`elixir --version`)
   - Erlang/OTP version
   - Bifrost gateway version, if relevant

If the bug is in the shape of the API itself (wrong field, missing
endpoint), it may originate in the upstream OpenAPI spec — link the relevant
part of the spec if you can.

## The most important thing to know: generated vs. persistent files

`lib/` and `mix.exs` are **generated** from `openapi-spec.yaml` and are
overwritten by every `./scripts/regenerate.sh` run. **Never hand-edit them**
— fixes belong in one of the persistent sources:

| To change… | Edit… |
| --- | --- |
| The API surface (endpoints, models) | `openapi-spec.yaml` (synced weekly from upstream — see `.spec-source`) |
| How code is generated | `.openapi-generator/templates/` (Mustache templates) |
| Post-generation transformations | `scripts/post-generate.sh` |
| Generator options | `generator-config.yaml` |
| Tests, config, scripts, workflows, docs | Directly — they are protected via `.openapi-generator-ignore` |

After changing the spec or a template, run `./scripts/regenerate.sh` and
review the resulting diff in `lib/`.

## Development Setup

Erlang/Elixir versions are pinned in `.tool-versions` (use
[asdf](https://asdf-vm.com) or [mise](https://mise.jdx.dev)). Regeneration
additionally needs OpenAPI Generator (Homebrew, npm, or Docker) and `jq`.

```bash
git clone https://github.com/houllette/ex_bifrost.git
cd ex_bifrost

# Enable the versioned git hooks (keeps the committed SBOM in sync)
git config core.hooksPath .githooks

mix deps.get
mix check   # full quality gate — mirrors CI
```

## Pull Requests

1. **Fork or branch** from `main`
2. **Make your changes** in the persistent sources (see table above)
3. **Add or update tests** — coverage is enforced at ≥90% (`mix coveralls`);
   the reflection-driven surface tests in `test/unit/` cover the generated
   code automatically, so new tests should target behavior, edge cases, and
   anything hand-written
4. **Run `mix check` before pushing** — it mirrors the CI gate (unused deps,
   compile with warnings-as-errors, format, credo strict, tests)
5. **Use Conventional Commit messages** — release automation derives version
   bumps and the CHANGELOG from them

### Conventional Commits

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org):

```
feat: add streaming support to chat completions
fix: handle 429 responses in retry middleware
docs: clarify virtual key configuration
chore: bump dependencies
feat!: rename connection option base_url to endpoint
```

- `feat:` → minor version bump, `fix:` → patch, `feat!:`/`BREAKING CHANGE:`
  → major (once past 1.0)
- `docs:`, `chore:`, `ci:`, `test:`, `refactor:` don't trigger releases
- CI enforces the format on PR titles and commits

### PR checklist

- [ ] Changes are in persistent sources, not hand-edits to `lib/`/`mix.exs`
- [ ] `mix check` passes locally
- [ ] Coverage stays ≥90% (`mix coveralls`)
- [ ] Dialyzer passes if you touched typespecs or templates (`mix dialyzer`)
- [ ] Commit messages are Conventional Commits

## Code Style

- `mix format` before committing (CI enforces `--check-formatted`)
- `mix credo --strict` must pass — generated `lib/` has scoped exemptions in
  `.credo.exs`; hand-written code is held to the full standard
- Typespecs on public functions; Dialyzer runs in CI
- Keep lines under 120 characters

## Testing

```bash
mix test                                  # all tests
mix test test/unit/connection_test.exs    # one file
mix coveralls                             # with the 90% floor
```

- **Use the harness in `test/support/`**: `use TestCase` (Mox helpers),
  `MockServer` (Bypass-backed mock HTTP server), and `Fixtures`
- Use `async: true` unless a test shares global state
- The surface tests (`test/unit/model_surface_test.exs`,
  `test/unit/api_surface_test.exs`) automatically cover newly generated
  operations and models after a spec update — flesh out targeted tests for
  behavior that matters (error mapping, retries, encoding edge cases)
- Retries are idempotent-only by design: the generated `Connection` never
  retries POSTs. Don't change that default without a very good reason.

## Regenerating the SDK

```bash
./scripts/validate-spec.sh   # validate openapi-spec.yaml
./scripts/regenerate.sh      # regenerate lib/ and mix.exs
```

The weekly spec-sync workflow opens a PR when the upstream Bifrost spec
changes. Known upstream spec issues that are patched locally are documented
in `AGENTS.md` — if a sync PR reintroduces one, re-apply the patch there.

## Release Process

Releases are automated from Conventional Commits — do **not** bump versions
or edit the CHANGELOG by hand:

1. `mix git_ops.release` (append `--initial` only for a repo's first
   release) — bumps `@version` in mix.exs, regenerates the CHANGELOG
   section, and creates the `vX.Y.Z` tag
2. `git push --follow-tags`
3. The tag push triggers the publish workflow: tests, docs build, publish to
   Hex.pm, and a GitHub Release

## Questions?

- Open an issue for questions
- Check existing issues and discussions
- See `AGENTS.md` for the full command reference and project conventions

## License

By contributing, you agree that your contributions will be licensed under
the MIT License.
