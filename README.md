# tinkle-kafka-events

> **Apache Avro schemas for Tinkle Messenger Kafka CDC events.**
> Centralized, versioned, schema-registry-ready event contracts across all microservices.

[![Organization: tinklehq](https://img.shields.io/badge/org-tinklehq-blueviolet)](https://github.com/tinklehq)
[![Schemas: Apache Avro](https://img.shields.io/badge/schemas-Apache%20Avro-1f6feb)](https://avro.apache.org/)
[![Wire format: Kafka](https://img.shields.io/badge/wire-Kafka-231f20)](https://kafka.apache.org/)
[![Status: v0 (WIP)](https://img.shields.io/badge/status-v0%20WIP-orange)]()

---

## What is this?

`tinkle-kafka-events` is the **single source of truth** for the event
schemas that flow through Tinkle Messenger's internal Kafka topics.
Every domain event produced by a service and consumed by one or more
downstream services is defined here as an **Apache Avro `.avsc` file**.

The repository exists to:

1. **Centralize the contract.** All event definitions live in one
   place, with one review process and one release cadence.
2. **Enable schema-registry workflows.** Every `.avsc` file is
   registered with a Schema Registry (Confluent-compatible) so
   compatibility is checked at publish time, not at runtime.
3. **Support polyglot clients.** Avro has first-class code generation
   for Go (`avrogen`), Java, Python, Kotlin, TypeScript, Rust, and
   Elixir.
4. **Provide a public, auditable record.** This repo is the
   human-readable "API documentation" for the internal event bus.

## Why Avro?

| Concern                     | Avro                                               |
| --------------------------- | -------------------------------------------------- |
| Wire size on the topic      | ~50–70% smaller than equivalent JSON               |
| Schema enforcement          | Mandatory at publish time via Schema Registry      |
| Forward / backward compat   | Built into the spec — enforced automatically       |
| Code generation             | First-class for Go, Java, Python, Kotlin, etc.     |
| Polyglot consumers          | Decoupled from any one IDL                         |
| Human readability           | Schemas are JSON — diff-friendly, PR-friendly      |

## Layout

```
tinkle-kafka-events/
├── README.md                          # you are here
├── docs/
│   ├── architecture.md                # event-flow diagram
│   ├── envelope.md                    # envelope pattern rationale
│   ├── compatibility.md               # BACKWARD / FORWARD / FULL policy
│   └── subject-naming.md              # schema-registry subject conventions
├── schemas/
│   ├── common/                        # shared types (envelope, enums)
│   ├── user/                          # user-service events
│   ├── chat/                          # chat/muc-service events
│   ├── roster/                        # roster-service events
│   ├── peer/                          # peer-block events
│   ├── privacy/                       # per-kind privacy events
│   ├── message/                       # chatroom message events
│   ├── muc/                           # muc-to-bot routing events
│   └── bot/                           # bot-service events
├── scripts/
│   └── validate.sh                    # fastavro-based Avro schema validator
└── .github/
    └── workflows/
        └── schema-compatibility.yml   # CI: validate schemas + register against staging registry
```

## Services & Topics Covered

See each `schemas/<service>/README.md` for the per-event breakdown.
At a glance:

| Producer       | Topic(s)                                   |
| -------------- | ------------------------------------------ |
| `user`         | `outbox.user.event`                        |
| `chat` (muc)   | `outbox.chat.event`                        |
| `roster`       | `outbox.roster.event`                      |
| `chat` (peer)  | `outbox.peer.event`                        |
| `privacy`      | `outbox.privacy.<kind>` for 6 kinds        |
| `chat` (msg)   | (see `schemas/message/README.md`)          |
| `muc`          | `outbox.muc.message`                       |
| `bot`          | `outbox.bot.event`                         |

## Envelope design

Every Avro record published to Kafka follows the **envelope pattern**
so that infrastructure can route, log, trace, and replay events
without understanding the payload.

```jsonc
{
  "type": "record",
  "name": "Envelope",
  "namespace": "io.tinklehq.events.common.v1",
  "fields": [
    { "name": "event_id",      "type": "string"  },            // UUIDv7
    { "name": "event_type",    "type": "string"  },            // e.g. "user_created"
    { "name": "aggregate_type","type": "string"  },            // e.g. "event"
    { "name": "aggregate_id",  "type": "string"  },            // Kafka key
    { "name": "occurred_at",   "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "schema_version","type": "int"     },            // 1
    { "name": "payload_schema","type": "string"  },            // FQN of payload record
    { "name": "traceparent",   "type": ["null", "string"], "default": null },
    { "name": "producer",      "type": ["null", "string"], "default": null },
    { "name": "payload",       "type": "bytes"   }             // Avro-encoded concrete event
  ]
}
```

See [`docs/envelope.md`](docs/envelope.md) for the full producer and
consumer flow.

## Compatibility policy

All schemas in this repo MUST be evolved under **BACKWARD** compatibility
(new consumers can read old data — the default in Confluent Schema Registry).

* Adding a new field → MUST have a `default`.
* Removing a field → MUST only remove fields that have a `default`.
* Changing a field's type → MUST be a safe promotion (`int` → `long`,
  `float` → `double`).
* Changing an enum → Adding a new symbol is allowed; renaming or
  reordering is not.

See [`docs/compatibility.md`](docs/compatibility.md) for the full ruleset.

## Versioning

Schemas are versioned in the **Avro namespace**, not the file name:

```
io.tinklehq.events.<service>.<event_type>.v1
io.tinklehq.events.<service>.<event_type>.v2   // breaking → new version under same subject
```

Bumping `v1` → `v2` is a **breaking** change. The new version is
registered under the same subject, the old version is frozen.

## Contributing

1. Branch from `main` using a `feature/<short-desc>` naming convention.
2. Add or modify `.avsc` files in the appropriate `schemas/<service>/`
   directory.
3. Run `./scripts/validate.sh` locally to confirm syntactic validity.
4. Open a PR — CI validates the schemas and (when configured) registers
   the candidate schemas against the staging Schema Registry, failing
   the PR on a `409 Conflict` (incompatibility).
5. After approval, merge via squash-commit. CI promotes the new version.

## License

Internal / proprietary to Tinkle Messenger. All rights reserved.
