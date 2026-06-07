# Architecture

> How the schemas in this repo fit into Tinkle Messenger's event-driven
> back-end.

## Components

```
+----------------------+    +---------------------+    +---------------+    +----------------------+
| Producer Service     |    |   PostgreSQL        |    |   Debezium    |    | Consumer Service     |
| (e.g. user-svc)      |    |                     |    |  Connector    |    | (e.g. roster-svc)    |
|                      |    |  domain table       |    |               |    |                      |
|  Business logic      |--->|  outbox table       |--->|  Kafka topic  |--->|  CDC consumer        |
|  + outbox insert     |    |  (same TX)          |    |               |    |  + handler           |
+----------------------+    +---------------------+    +---------------+    +----------------------+
          |                                                                    ^
          | produces                                                           | validates against
          v                                                                    |
     +------------------------------------------------------------------+
     |              tinkle-kafka-events  (this repository)              |
     |  Protobuf `.proto` schemas (Buf-managed) registered with          |
     |  Confluent Schema Registry in `schemaType: PROTOBUF` mode        |
     +------------------------------------------------------------------+
```

## Data flow

1. **Producer** mutates a domain table and, in the **same transaction**,
   inserts a row into the matching `<entity>_outbox` table.
2. **Debezium** captures the `INSERT` from the outbox table via logical
   replication and publishes a CDC record to a Kafka topic.
3. **Consumer** reads the topic, deserialises the message using the
   Schema-Registry-resolved Protobuf schema (via
   `KafkaProtobufDeserializer` / `confluent-kafka-go`'s `ProtoDeserializer`),
   and applies the change to its local projection.
4. **Schema registry** acts as the contract enforcer. Compatibility is
   checked at publish time; a producer cannot push a schema that would
   break a registered consumer.

## Topic topology

The current back-end uses a **per-aggregate** topic strategy. Each
producer service publishes to one (or several) topics:

| Producer       | Kafka topic(s)                                   |
| -------------- | ------------------------------------------------ |
| user-service   | `outbox.user.event`                              |
| chat (muc)     | `outbox.chat.event`                              |
| roster-service | `outbox.roster.event`                            |
| chat (peer)    | `outbox.peer.event`                              |
| privacy-svc    | `outbox.privacy.<kind>` for 6 kinds              |
| muc            | `outbox.muc.message`                             |
| bot-service    | `outbox.bot.event`                               |

Within a topic, the Kafka **message key** is the `aggregate_id` field
of the envelope. This guarantees that all events for the same aggregate
land on the same partition and are processed in order.

## Per-topic subject strategy

In Confluent Schema Registry, the **subject** is a logical namespace
for a schema's history. We use the **TopicNameStrategy** (the default
and the recommended setting for most deployments):

| Kafka topic               | Subject                       | Schema(s) registered                                |
| ------------------------- | ----------------------------- | --------------------------------------------------- |
| `outbox.user.event`       | `outbox.user.event-value`     | `me.tinkle.events.common.v1.Envelope` (the wrapper) |
| `outbox.roster.event`     | `outbox.roster.event-value`   | `Envelope`                                          |
| `outbox.privacy.call`     | `outbox.privacy.call-value`   | `Envelope`                                          |
| ...                       | ...                           | ...                                                 |

The Envelope wraps a single concrete event record (per-event schema).
The Envelope's `payload` field is `bytes`; the consumer looks up the
concrete schema by `event_type` and decodes accordingly.

> See `subject-naming.md` for the full rationale.

## What this repo is

This Protobuf repository is the **authoritative wire contract** for
every Kafka CDC event in the Tinkle stack. It provides:

* A **polyglot** contract for non-Go consumers (Elixir chat-node,
  Java/Kotlin mobile gateways, Python analytics, future Rust services).
* A **schema-registry-friendly** format with native compatibility
  checking, code generation, and runtime validation.
* A **public, audit-friendly** record of the data contract — `.proto`
  files are textual, easy to diff and review in PRs.
* A **Buf-managed** module: `buf lint` enforces the `STANDARD` style
  category on every PR; `buf breaking --against '.git#branch=main'`
  blocks any wire-incompatible change before it lands.

The repo is deliberately standalone: nothing here references or
depends on any other repository. Each `.proto` is a self-contained
contract, registered with Confluent Schema Registry in `PROTOBUF` mode
and consumed by any service that wants to read or write the
corresponding topic.
