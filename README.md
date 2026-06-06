# tinkle-kafka-events

> **Apache Avro schemas for Tinkle Messenger Kafka CDC events.**
> Centralized, versioned, schema-registry-ready event contracts across all microservices.

[![Organization: tinklehq](https://img.shields.io/badge/org-tinklehq-blueviolet)](https://github.com/tinklehq)
[![Schemas: Apache Avro](https://img.shields.io/badge/schemas-Apache%20Avro-1f6feb)](https://avro.apache.org/)
[![Wire format: Kafka](https://img.shields.io/badge/wire-Kafka-231f20)](https://kafka.apache.org/)
[![Status: v0 (WIP)](https://img.shields.io/badge/status-v0%20WIP-orange)]()

---

## What is this?

`tinkle-kafka-events` is the **single source of truth** for the event schemas that
flow through [Tinkle Messenger](https://github.com/tinklehq)'s internal Kafka
topics. Every domain event published by an upstream service and consumed by one
or more downstream services is defined here as an **Apache Avro `.avsc`** file.

The repository exists to:

1. **Eliminate drift.** Producers and consumers evolve from a shared contract
   instead of hand-copying `.proto` definitions.
2. **Enable schema-registry workflows.** Every `.avsc` file is registered with
   a Schema Registry (Confluent-compatible) so compatibility is checked at
   publish time, not at runtime.
3. **Support polyglot clients.** Avro has first-class code generation for Go
   (`avrogen`), Java, Python, Kotlin, TypeScript, Rust, and Elixir.
4. **Provide a public, auditable record.** This repo is the human-readable
   "API documentation" for our internal event bus.

## Why Avro?

| Concern                     | Avro                                               |
| --------------------------- | -------------------------------------------------- |
| Wire size on the topic      | ~50–70% smaller than equivalent JSON               |
| Schema enforcement          | Mandatory at publish time via Schema Registry      |
| Forward / backward compat   | Built into the spec — enforced automatically       |
| Code generation             | First-class for Go, Java, Python, Kotlin, etc.     |
| Polyglot consumers          | Decoupled from any one IDL (Protobuf, Thrift, …)   |
| Human readability           | Schemas are JSON — diff-friendly, PR-friendly      |

> The existing `proto/internal/outbox/v1/outbox.proto` definitions remain the
> authoritative Go source of truth for now. This repo **mirrors** them in Avro
> so that non-Go consumers (Elixir chat-node, Java/Kotlin mobile gateways,
> Python analytics) can deserialize events without re-deriving the contract.

## Layout

This repository's contents will land on a feature branch once the initial
schemas are authored. The planned directory layout is:

```
tinkle-kafka-events/
├── README.md                          # you are here
├── docs/
│   ├── architecture.md                # event-flow diagram
│   ├── envelope.md                    # envelope pattern rationale
│   ├── compatibility.md              # BACKWARD / FORWARD / FULL policy
│   └── subject-naming.md              # schema-registry subject conventions
├── schemas/
│   ├── common/                        # shared types (envelope, enums)
│   │   ├── envelope.avsc
│   │   ├── enums.avsc
│   │   └── snowflake.avsc
│   ├── user/                          # user-service events
│   ├── chat/                          # chat/muc-service events
│   ├── roster/                        # roster-service events
│   ├── peer/                          # peer-block events
│   ├── privacy/                       # per-kind privacy events
│   ├── message/                       # chatroom message events
│   ├── muc/                           # muc-to-bot routing events
│   └── bot/                           # bot-service events
├── scripts/
│   └── validate.sh                    # avro-tools compatibility check
└── .github/
    └── workflows/
        └── compatibility.yml          # CI: register + diff schemas
```

## Services & Topics Covered

The schemas in this repo cover the CDC events consumed via the
`cdcevent` library in
[`tinklehq/tinkle-server`](https://github.com/tinklehq/tinkle-server):

| Producer service | Kafka topic                       | Aggregate   | Events                                                                       |
| ---------------- | --------------------------------- | ----------- | ---------------------------------------------------------------------------- |
| `user`           | `outbox.user.event`               | `event`     | `UserCreatedEvent`, `UserDeletedEvent`                                        |
| `chat` (muc)     | `outbox.chat.event`               | `event`     | `ChatCreatedEvent`, `ChatDeletedEvent`                                        |
| `roster`         | `outbox.roster.event`             | `event`     | `RosterContactAddedEvent`, `RosterContactDeletedEvent`, `RosterClearedEvent`, `RosterContactBatchAddedEvent`, `RosterContactBatchDeletedEvent`, `MutualContactEstablishedEvent`, `MutualContactBrokenEvent` |
| `chat` (peer)    | `outbox.peer.event`               | `event`     | `PeerUserBlockedEvent`, `PeerUserUnblockedEvent`                              |
| `privacy`        | `outbox.privacy.call`             | `call`      | `UpsertCallPrivacyEvent`, `UpsertCallPrivacyRuleEvent`, `RemoveCallPrivacyRuleEvent` |
| `privacy`        | `outbox.privacy.presence`         | `presence`  | `UpsertPresencePrivacyEvent`, `UpsertPresencePrivacyRuleEvent`, `RemovePresencePrivacyRuleEvent` |
| `privacy`        | `outbox.privacy.phone_number`     | `phone_number` | `UpsertPhoneNumberPrivacyEvent`, `UpsertPhoneNumberPrivacyRuleEvent`, `RemovePhoneNumberPrivacyRuleEvent` |
| `privacy`        | `outbox.privacy.about`            | `about`     | `UpsertAboutPrivacyEvent`, `UpsertAboutPrivacyRuleEvent`, `RemoveAboutPrivacyRuleEvent` |
| `privacy`        | `outbox.privacy.profile_photo`    | `profile_photo` | `UpsertProfilePhotoPrivacyEvent`, `UpsertProfilePhotoPrivacyRuleEvent`, `RemoveProfilePhotoPrivacyRuleEvent` |
| `privacy`        | `outbox.privacy.chat_invite`      | `chat_invite` | `UpsertChatInvitePrivacyEvent`, `UpsertChatInvitePrivacyRuleEvent`, `RemoveChatInvitePrivacyRuleEvent` |
| `muc`            | `outbox.muc.message`              | `message`   | `MessageToBot`                                                                |
| `bot`            | `outbox.bot.event`                | `event`     | `BotMessageCreated`, `BotMessageEdited`, `BotMessageDeleted`, `BotCallbackQuery` |
| `chat`           | *(protobuf-defined)*              |             | `MessageCreatedEvent`, `MessageDeletedEvent`, `MessageRevokedEvent`            |

## Envelope design (preview)

Every Avro record published to Kafka follows the **envelope pattern** so that
infrastructure can route, log, trace, and replay events without understanding
the payload.

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
    { "name": "traceparent",   "type": ["null", "string"], "default": null },
    { "name": "payload",       "type": "bytes"   }             // Avro-encoded concrete event
  ]
}
```

The full envelope schema, enum definitions, and per-service event payloads
land in the `feature/initial-avro-schemas` branch (coming next).

## Compatibility policy

All schemas in this repo MUST be evolved under **BACKWARD** compatibility
(new consumers can read old data — the default in Confluent Schema Registry).

* Adding a new field → MUST have a `default`.
* Removing a field → MUST only remove fields that have a `default`.
* Changing a field's type → MUST be a safe promotion (`int` → `long`,
  `float` → `double`).
* Changing an enum → Adding a new symbol is allowed; renaming or reordering
  is not.

See `docs/compatibility.md` for the full ruleset.

## Versioning

Schemas are versioned in the **Avro namespace**, not the file name:

```
io.tinklehq.events.<service>.<event_type>.v1
io.tinklehq.events.<service>.<event_type>.v2   // breaking → new subject
```

Bumping `v1` → `v2` is a **breaking** change. A breaking change creates a
new Schema Registry subject and the old subject is frozen (still readable
by old consumers).

## Contributing

1. Branch from `main` using a `feature/<short-desc>` naming convention.
2. Add or modify `.avsc` files in the appropriate `schemas/<service>/` directory.
3. Run `scripts/validate.sh` locally to confirm syntactic validity.
4. Open a PR — CI will register the candidate schema against Schema Registry
   and reject the change if it is incompatible with the latest version.
5. After approval, merge via squash-commit. CI promotes the new version.

## Related repositories

* [`tinklehq/tinkle-server`](https://github.com/tinklehq/tinkle-server) — the
  Go microservices that produce and consume these events. `src/libs/cdcevent`
  holds the Go-side discriminator constants and topic names.
* [`tinklehq/outbox-proto`](https://github.com/tinklehq/outbox-proto) — the
  **Protobuf** mirror of these events for Go-only consumers. Will be
  deprecated in favour of this Avro repo once adoption is complete.
* [`tinklehq/tinkle-proto`](https://github.com/tinklehq/tinkle-proto) — the
  **public** client-facing gRPC API contracts (not internal CDC events).

## License

Internal / proprietary to Tinkle Messenger. All rights reserved.
