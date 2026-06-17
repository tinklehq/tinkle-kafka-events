# AGENTS

This file is the entrypoint for AI coding agents working in this
repository. Read it fully before making any non-trivial change.

## TL;DR

- **`tinklehq/tinkle-kafka-events`** is the source of truth for the
  Kafka CDC event Protobuf contract. The repo contains the `.proto`
  files and Buf config only.
- The schema is published to the Buf Schema Registry at
  **`buf.build/tinklecorp/tinkle-kafka-events`** (public). The BSR
  generates and serves **Go** SDKs to consumers; no language-specific
  code lives in this repo.
- The `.proto` files are **maintained directly in this repo** under
  `proto/<service>/v1/`. There is no upstream mirror; this is the
  only place the contract is edited.
- **No release-please, no per-language tags, no generated code in
  the tree.** Bump a version on the BSR by pushing a new commit;
  consumers update via `go get @latest`.

## Architecture

```
tinklehq/tinkle-kafka-events (this repo)    proto source + Buf config
├── proto/                                   proto source (owned here)
│   ├── bot/v1/                              bot-service events
│   ├── chat/v1/                             chat-service events
│   ├── common/v1/                           envelope + shared enums
│   ├── message/v1/                          chatroom message events
│   ├── muc/v1/                              muc-to-bot routing events
│   ├── peer/v1/                             peer-block events
│   ├── privacy/v1/                          per-kind privacy events
│   ├── roster/v1/                           roster-service events
│   └── user/v1/                             user-service events
├── buf.yaml                                 v2 single-module workspace
│                                            name: buf.build/tinklecorp/tinkle-kafka-events
├── buf.lock                                 generated (no module deps currently)
├── LICENSE                                  Apache 2.0 (required for pkg.go.dev)
├── README.md
├── AGENTS.md
├── CONTRIBUTING.md
└── .github/workflows/buf-ci.yaml            bufbuild/buf-action@v1:
                                              build/lint/format/breaking/push
```

The BSR takes care of everything else: published module, generated
SDKs, version history, generated documentation, and dependency
resolution. See <https://buf.build/tinklecorp/tinkle-kafka-events>
for the live state.

The Confluent Schema Registry is still used at runtime by Kafka
producers and consumers (the `KafkaProtobufSerializer` resolves the
schema-ID prefix via Confluent SR); the BSR is the *source of truth*
that is synced into Confluent SR via the deploy pipeline, not via
this repo's CI.

## Consumer dependencies

The BSR auto-versions each push. SDK versions are
`{plugin-version}-{module-commit-timestamp}-{module-commit-id}.{plugin-revision}`
(e.g. `v1.36.11-20260617120000-abc123def456.1`). Pin with
`@vX.Y.Z-…`, `@<commit-id>`, or `@<label>`.

| Language | Command |
|----------|---------|
| Go (Protobuf) | `go get buf.build/gen/go/tinklecorp/tinkle-kafka-events/protocolbuffers/go` |
| Go (gRPC)     | `go get buf.build/gen/go/tinklecorp/tinkle-kafka-events/grpc/go` |

The two Go modules must be pinned to the same module commit (the
timestamp and short-id segments) so the message types and the gRPC
stubs stay in sync.

```go
import (
    envelope "buf.build/gen/go/tinklecorp/tinkle-kafka-events/protocolbuffers/go/tinkle/events/common/v1;tinkleeventscommonv1"
)
```

## Conventions for agents

1. **Edit `.proto` files in place under `proto/<service>/v1/`.** This
   repo is the only place the contract is maintained. There is no
   mirror from any other repo — proto changes land here directly.
   Keep the Protobuf `package tinkle.events.<service>.v1;` and
   the `option go_package = "github.com/tinklehq/tinkle-kafka-events/proto/<service>/v1;tinkleevents<service>v1";`
   line consistent across all files in the package.
2. **`buf push` is automatic on merge to `main`.** The `buf-ci.yaml`
   workflow uses `bufbuild/buf-action@v1`; on push to `main` it
   publishes the named module to the BSR with the matching Git
   metadata.
3. **`BUF_TOKEN` secret is required.** A BSR API token for the
   `tinklecorp` org must be configured as a repository secret
   (Settings → Secrets and variables → Actions) before the first
   merge to `main`, otherwise the initial `buf push` will fail and
   the BSR module will not be created. The action auto-creates the
   BSR repo on first push; `push_create_visibility: public` makes
   that explicit.
4. **Lint before pushing.** Run `buf format -d` and `buf lint`
   locally; the `buf-ci.yaml` action will run them on every PR and
   fail the build on findings.
5. **Breaking changes are blocked by `buf breaking`** in CI (the
   `breaking: FILE` category from `buf.yaml`). For intentional
   structural migrations (e.g. a directory rename), add a
   `buf skip breaking` label to the PR (Issues → Labels in the repo
   settings) — the action checks for the label and skips the
   breaking step. For permanent wire breaks, add a new package path
   (`tinkle.events.<service>.v2/`) rather than mutating the
   existing `v1/` files.
6. **No `buf generate`, no `buf.gen.yaml`.** Code generation
   happens on the BSR. A `buf.gen.yaml` only exists if you need
   to run `buf generate` against a third-party plugin locally;
   in this repo, there is none.
7. **`PACKAGE_DIRECTORY_MATCH` is intentionally excepted.** The
   Protobuf packages are `tinkle.events.<service>.v1` but the
   directories are `proto/<service>/v1/`. This is the same exception
   `tinklehq/tinkle-proto` makes — the path-flattening is for
   ergonomic review; the package name is the wire contract and
   stays deep. See `buf.yaml`.

## When asked to "add a new event"

1. Open a PR in this repo (`tinklehq/tinkle-kafka-events`) adding
   `<event_name>.proto` under `proto/<service>/v1/`. Use the
   existing files in the same directory as a template. Keep the
   Protobuf `package` and `option go_package` lines as they are.
2. The buf-ci action on the PR runs `build`, `lint`, `format`, and
   `breaking` (against the base branch) and posts a summary comment.
   Fix any findings.
3. Merge to `main`. The action runs `buf push`, which publishes a
   new commit to the BSR. The BSR serves the updated Go SDK lazily —
   consumers pick it up with `go get @latest`.

## When asked to "fix generated code"

Don't try to fix generated code in this repo — there is no
generated code in this repo. Edit the `.proto` source in
`proto/<service>/v1/` directly; the BUF_CI push run on merge will
republish the schema to the BSR, and consumers will pick up the
regenerated SDKs on their next `go get`.

## Local validation

```bash
buf format -d
buf lint
buf breaking --against ".git#branch=origin/main"
buf build
```

These are the same checks the `buf-ci.yaml` action runs on every
PR. There is no local `buf generate` step.

## CI workflow

`.github/workflows/buf-ci.yaml` runs `bufbuild/buf-action@v1`,
which on every PR runs `build`, `lint`, `format`, and `breaking`,
and on every push to `main` also runs `buf push` (publishing to
the BSR). On a branch delete, the action archives the matching
BSR label. The action posts a PR summary comment keyed on
`<workflow>:<job>`.

## BSR resource

- Module: <https://buf.build/tinklecorp/tinkle-kafka-events>
- Generated SDKs: <https://buf.build/tinklecorp/tinkle-kafka-events/sdks>
- Documentation: <https://buf.build/tinklecorp/tinkle-kafka-events/docs>
