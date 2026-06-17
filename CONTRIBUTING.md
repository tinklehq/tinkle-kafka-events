# Contributing to tinkle-kafka-events

## Source of truth

The `.proto` files under `proto/<service>/v1/` are the canonical
event contracts for the Tinkle Kafka CDC pipeline. This repo is the
**only** place the contract is maintained. There is no mirror from
any other repo — proto changes land here directly.

The schema is auto-published to the
[Buf Schema Registry](https://buf.build/tinklecorp/tinkle-kafka-events)
on every merge to `main`. The BSR generates the Go SDK that all
Tinkle back-end services consume.

## How a proto change flows to consumers

1. Edit `proto/<service>/v1/*.proto` in `tinklehq/tinkle-kafka-events`
   in a feature branch.
2. Open a PR. The `buf-ci` workflow runs `buf lint`, `buf format`,
   and `buf breaking` (against the base branch) and posts a
   summary comment. Fix any findings.
3. Merge to `main`. The workflow runs `buf push` automatically,
   publishing a new module commit to the BSR.
4. Consumers pick up the new contract on their next
   `go get buf.build/gen/go/tinklecorp/tinkle-kafka-events/protocolbuffers/go@latest`.

## Local validation

From the repo root:

```bash
buf format -d
buf lint
buf breaking --against ".git#branch=origin/main"
buf build
```

These are the same checks the `buf-ci` workflow runs on every PR.
There is no local `buf generate` step — code generation happens on
the BSR.

## Conventional commits

This repo does not use release-please. Every push to `main`
auto-bumps the BSR version (each push is a new module commit).
Consumers pin to specific versions via `@vX.Y.Z-…`, `@<commit-id>`,
or `@<label>`.

Use the standard Conventional Commits prefixes on your commit
messages so that `git log` is readable:

| Prefix              | SemVer bump | Notes                                      |
|---------------------|-------------|--------------------------------------------|
| `feat:`             | minor (BSR) | New event, new field                       |
| `fix:`              | patch (BSR) | Behavior-preserving bug fix                |
| `feat!:` / `BREAKING CHANGE:` | major (BSR) | Reserved for `v2` packages; do not use in `v1` |
| `perf:`             | patch (BSR) | Performance improvement                    |
| `refactor:`         | — (BSR bump) | Internal refactor; no schema change      |
| `chore:` / `build:` / `ci:` / `docs:` / `style:` / `test:` | — (BSR bump) | Never break the schema                    |

The "BSR bump" column is informational — every merge to `main`
produces a new module commit, but the *contract* (wire format) is
unchanged unless the commit type signals a breaking change.

## Breaking changes

`buf breaking` runs on every PR with the `FILE` category (the
strictest — catches anything that would break generated code). For
intentional breaks, add the `buf skip breaking` label to the PR
(Issues → Labels in the repo settings); the action checks for the
label and skips the breaking step. For permanent breaks, add a new
package path (`me.tinkle.events.<service>.v2/`) rather than
mutating the existing `v1/` files.

## Common tasks

| Task | Where to make the change |
|---|---|
| Add a new event | `tinklehq/tinkle-kafka-events` — open a PR adding `<event>.proto` under `proto/<service>/v1/` |
| Add a new field to an existing event | same — keep `BACKWARD_TRANSITIVE` (use a fresh tag number) |
| Bump an event to a breaking new version | new package `me.tinkle.events.<service>.v2/...` under `proto/<service>/v2/` |
| Rename a field | use `[deprecated = true]` on the old field, add the new one with a new tag, do not rename in place |
| Add a new language SDK | request it on the BSR; no repo change needed unless you also want a `buf.gen.yaml` for local codegen |
| Change BSR module ownership / name | `buf.yaml` (`modules[0].name`) — coord with the tinklecorp BSR org admins |

## CI / required secrets

`BUF_TOKEN` — a BSR API token for the `tinklecorp` org, configured
as a repository secret (Settings → Secrets and variables → Actions).
The action auto-creates the BSR repo on first push; `push_create_visibility: public`
is set explicitly. Without `BUF_TOKEN`, the first push fails and
the BSR module is not created.
