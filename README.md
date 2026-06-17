# tinkle-kafka-events

> **Protobuf + Buf schemas for Tinkle Messenger Kafka CDC events.**
> Centralized, versioned, BSR-published event contracts across all
> microservices.

[![Organization: tinklehq](https://img.shields.io/badge/org-tinklehq-blueviolet)](https://github.com/tinklehq)
[![Schemas: Protobuf](https://img.shields.io/badge/schemas-Protobuf-1f6feb)](https://protobuf.dev/)
[![Buf: STANDARD](https://img.shields.io/badge/buf-STANDARD-blue)](https://buf.build/docs/lint/rules/)
[![Wire format: Kafka](https://img.shields.io/badge/wire-Kafka-231f20)](https://kafka.apache.org/)
[![BSR: tinklecorp/tinkle-kafka-events](https://img.shields.io/badge/BSR-tinklecorp%2Ftinkle--kafka--events-2d7cb8)](https://buf.build/tinklecorp/tinkle-kafka-events)

---

## What is this?

`tinkle-kafka-events` is the **single source of truth** for the event
schemas that flow through Tinkle Messenger's internal Kafka topics.
Every domain event produced by a service and consumed by one or more
downstream services is defined here as a **Protobuf `.proto` file**,
managed with the [Buf](https://buf.build) toolchain.

The `.proto` files are auto-mirrored to the
[Buf Schema Registry](https://buf.build/tinklecorp/tinkle-kafka-events)
(public), which generates and serves the **Go** SDK to consumers
across the Tinkle back-end. This repo contains the proto source and
the Buf config — no per-language code lives here.

The repository exists to:

1. **Centralize the contract.** All event definitions live in one
   place, with one review process and one release cadence.
2. **Enable BSR-first schema workflows.** Every `.proto` file is
   published to `buf.build/tinklecorp/tinkle-kafka-events`, with
   versioned commit history, generated Go SDKs, and documentation.
3. **Support polyglot clients.** Protobuf has first-class code
   generation for Go, Java, Python, Kotlin, TypeScript, Rust, Elixir,
   C++, and more — and the BSR will produce any of them from this
   single module on demand.
4. **Provide a public, auditable record.** This repo is the
   human-readable "API documentation" for the internal event bus.

## Why Protobuf (+ Buf)?

| Concern                     | Protobuf + Buf                                      |
| --------------------------- | --------------------------------------------------- |
| Wire size on the topic      | ~30–50% smaller than equivalent Avro; smaller than JSON |
| Schema enforcement          | Mandatory at publish time via Confluent SR          |
| Forward / backward compat   | `BACKWARD_TRANSITIVE` checked automatically         |
| Code generation             | BSR generates Go SDKs from this module on push     |
| Lint & breaking-change CI   | Built-in (`buf lint`, `buf breaking`)                |
| Standardised style          | `buf format` + `STANDARD` lint category             |
| Polyglot consumers          | Decoupled from any one IDL (librdkafka union safe)  |
| Human readability           | `.proto` files are diff-friendly, PR-friendly       |

## Architecture

```
tinklehq/tinkle-kafka-events (this repo)    proto source + Buf config
├── proto/                                   proto source (owned here)
│   ├── bot/v1/                              bot-service events
│   ├── chat/v1/                             chat-service (chat-aggregate) events
│   ├── common/v1/                           envelope + shared enums
│   ├── message/v1/                          chatroom message events
│   ├── muc/v1/                              muc-to-bot routing events
│   ├── peer/v1/                             peer-block events
│   ├── privacy/v1/                          per-kind privacy events
│   ├── roster/v1/                           roster-service events
│   └── user/v1/                             user-service events
├── buf.yaml                                 v2 single-module workspace
│                                            name: buf.build/tinklecorp/tinkle-kafka-events
├── LICENSE                                  Apache 2.0 (required for pkg.go.dev)
├── README.md
└── .github/workflows/buf-ci.yaml            bufbuild/buf-action@v1:
                                              build/lint/format/breaking/push
```

The BSR takes care of everything else: published module, generated
SDKs, version history, generated documentation, and dependency
resolution. See <https://buf.build/tinklecorp/tinkle-kafka-events> for
the live state.

Producer services and any other microservice that publishes or
consumes these events should consume the BSR-published Go SDK — they
do not edit or mirror `.proto` files from this repo.

## Layout

```
tinkle-kafka-events/
├── README.md                          # you are here
├── buf.yaml                           # Buf v2 module config
│                                      #   name: buf.build/tinklecorp/tinkle-kafka-events
│                                      #   lint STANDARD, breaking FILE
├── LICENSE                            # Apache 2.0
├── docs/
│   ├── architecture.md                # event-flow diagram
│   ├── envelope.md                    # envelope pattern rationale
│   ├── compatibility.md               # BACKWARD_TRANSITIVE policy
│   └── subject-naming.md              # Confluent SR subject conventions
├── proto/
│   ├── bot/v1/                        # bot-service events
│   ├── chat/v1/                       # chat-service (chat-aggregate) events
│   ├── common/v1/                     # envelope + shared enums
│   ├── message/v1/                    # chatroom message events
│   ├── muc/v1/                        # muc-to-bot routing events
│   ├── peer/v1/                       # peer-block events
│   ├── privacy/v1/                    # per-kind privacy events
│   ├── roster/v1/                     # roster-service events
│   └── user/v1/                       # user-service events
└── .github/
    └── workflows/
        └── buf-ci.yaml                # CI: buf lint + buf breaking + buf push
```

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

The BSR also serves TypeScript/JavaScript, Python, Java/Kotlin, and
Swift SDKs against the same module on request.

## Services & topics covered

| Producer       | Topic(s)                                   |
| -------------- | ------------------------------------------ |
| `user`         | `outbox.user.event`                        |
| `chat` (muc)   | `outbox.chat.event`                        |
| `roster`       | `outbox.roster.event`                      |
| `chat` (peer)  | `outbox.peer.event`                        |
| `privacy`      | `outbox.privacy.<kind>` for 6 kinds        |
| `chat` (msg)   | (see `proto/message/v1/README.md`)         |
| `muc`          | `outbox.muc.message`                       |
| `bot`          | `outbox.bot.event`                         |

## Envelope design

Every Protobuf message published to Kafka follows the **envelope
pattern** so that infrastructure can route, log, trace, and replay
events without understanding the payload.

```proto
message Envelope {
  string                  event_id       = 1;  // UUIDv7
  string                  event_type     = 2;  // e.g. "user_created"
  string                  aggregate_type = 3;  // e.g. "event"
  string                  aggregate_id   = 4;  // Kafka key
  google.protobuf.Timestamp occurred_at   = 5;
  int32                   schema_version = 6;  // 1
  string                  payload_schema = 7;  // FQN of payload message
  string                  traceparent    = 8;
  string                  producer       = 9;
  bytes                   payload        = 10; // Protobuf-encoded concrete event
}
```

See [`docs/envelope.md`](docs/envelope.md) for the full producer and
consumer flow.

## Compatibility policy

All schemas in this repo MUST be evolved under
**`BACKWARD_TRANSITIVE`** compatibility (new consumers can read old
data, including across the full subject history). This is Confluent's
[recommended default for Protobuf](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html)
because adding new top-level messages is not forward compatible.

* Adding a new field → MUST use a fresh tag number.
* Removing a field → MUST add the tag to `reserved`; renaming a field
  is allowed (the tag is the identity) but `[deprecated = true]` is
  recommended for human readers.
* Changing a field's type → **NOT allowed**, even for the same-wire
  type pairs that Confluent's checker would permit (we treat them as
  breaking to keep consumers predictable across all client SDKs).
* Changing an enum → adding a new value is allowed; renaming or
  reordering is not (the integer ordinal is the wire identity).
* Adding a new top-level message → allowed under
  `BACKWARD_TRANSITIVE` (producers that publish the new event before a
  consumer has been updated will silently drop the new event — the
  consumer-side handling for this is the same `payload_schema`
  fallback as the Avro era).

See [`docs/compatibility.md`](docs/compatibility.md) for the full
ruleset.

## Versioning

Schemas are versioned in the **Protobuf package**, not the file name:

```
package tinkle.events.<service>.v1;
package tinkle.events.<service>.v2;  // breaking → new v2 files under same subject
```

Bumping `v1` → `v2` is a **breaking** change. The new version is
registered under the same Confluent SR subject, the old version is
frozen. On the BSR, both versions exist as separate module commits —
consumers pin to a specific version explicitly.

## Contributing

1. Branch from `main` using a `feature/<short-desc>` naming convention.
2. Add or modify `.proto` files in the appropriate
   `proto/<service>/v1/` directory. Keep the Protobuf `package tinkle.events.<service>.v1;`
   and the `option go_package = "github.com/tinklehq/tinkle-kafka-events/proto/<service>/v1;tinkleevents<service>v1";`
   line consistent across all files in the package.
3. Run `buf format -w` and `buf lint` locally; the `buf-ci.yaml`
   action will run them on every PR and fail the build on findings.
4. Open a PR — CI runs `buf lint`, `buf breaking`, and (on merge to
   `main`) `buf push` to the BSR. The breaking step also requires
   a `buf skip breaking` label on intentional structural migrations.
5. After approval, merge via squash-commit. CI publishes the new
   version to `buf.build/tinklecorp/tinkle-kafka-events`; consumers
   pick up the regenerated Go SDK on their next `go get @latest`.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full workflow and
[`AGENTS.md`](AGENTS.md) for the conventions that AI coding agents
MUST follow.

## License

[Apache 2.0](LICENSE) — copyright Tinkle Messenger. All rights
reserved.
