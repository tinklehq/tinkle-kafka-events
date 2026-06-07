# Envelope pattern

> Why every event in this repo is wrapped in a standard `Envelope`
> message before it hits Kafka.

## Definition

`proto/me/tinkle/events/common/v1/envelope.proto`:

```proto
syntax = "proto3";

package me.tinkle.events.common.v1;

import "google/protobuf/timestamp.proto";

message Envelope {
  string                     event_id       = 1;  // UUIDv7
  string                     event_type     = 2;  // e.g. "user_created"
  string                     aggregate_type = 3;  // e.g. "event"
  string                     aggregate_id   = 4;  // Kafka message key
  google.protobuf.Timestamp  occurred_at    = 5;
  int32                      schema_version = 6;  // 1
  string                     payload_schema = 7;  // FQN of payload message
  string                     traceparent    = 8;  // W3C trace context, "" if absent
  string                     producer       = 9;  // e.g. "user-service", "" if unset
  bytes                      payload        = 10; // Protobuf-encoded concrete event
}
```

## Wire format

Confluent's `KafkaProtobufSerializer` prepends a small header to every
serialised message:

```
+---------+--------------------+----------------------+--------------------+
| 1 byte  | 4 bytes (big-endian) | varint[] (zig-zag)   | n bytes           |
| 0x00    | schema ID          | message-index path   | protobuf payload  |
| magic   |                    | inside FileDescProto |                   |
+---------+--------------------+----------------------+--------------------+
```

* **Magic byte** `0x00` is identical to the Avro and JSON-Schema
  serializers, so the deserializer multiplexes by `schemaType`.
* **Schema ID** is a 4-byte integer that uniquely identifies the
  registered schema in Confluent SR for the topic's subject.
* **Message index** is a chain of `varint`-encoded integers pointing
  to the message descriptor inside the `FileDescriptorProto`. For
  top-level messages it's a single integer; for nested messages it's
  a chain like `[2, 0, 1]`.
* **Payload** is the standard Protobuf binary encoding of the
  message.

> See
> <https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/serdes-protobuf.html#wire-format>
> for the authoritative spec.

## Why an envelope?

A bare `UserCreatedEvent` on the wire is a perfectly valid Kafka
message, but it leaks responsibility onto the consumer: every consumer
must know the topic, guess at the schema version, parse a W3C
traceparent from a header, and so on.

The envelope is a deliberate separation of **routing concerns** from
**domain concerns**:

| Concern                          | Lives in envelope? | Lives in payload? |
| -------------------------------- | ------------------ | ----------------- |
| Trace propagation                | yes `traceparent`  |                  |
| Idempotency key                  | yes `event_id`     |                  |
| Routing (Kafka key)              | yes `aggregate_id` |                  |
| Producer attribution             | yes `producer`     |                  |
| Schema-Registry lookup hint      | yes `payload_schema`|                 |
| Wire compat for the event itself |                    | yes domain fields |

This pattern is endorsed by CloudEvents, CNCF's Serverless Working
Group, and most large Kafka shops (LinkedIn, Confluent, Uber).

## Why a generic `bytes` payload (not a `oneof`)?

The Confluent
[docs](https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/serdes-protobuf.html)
suggest using a `oneof` for multi-type topics, because Protobuf's
`oneof` is well-supported by `librdkafka`-based clients (unlike Avro
unions). So why don't we use it?

We deliberately don't, for one reason:

1. **Schema-explosion.** Every new event type would force the
   envelope's `oneof` to grow, creating a new envelope schema version
   for every event added to the topic. The envelope is meant to be
   stable for years; the `v1 → v2` deprecation dance
   ([`compatibility.md`](compatibility.md)) is only for true envelope
   evolution.

The `bytes` + `payload_schema` approach gives us:

* A **stable** envelope schema (one subject per topic, rarely
  versioned).
* **Generic deserialisation**: a consumer can decode the envelope
  without knowing which concrete event types exist, then look up the
  concrete schema by name and dispatch.

The `librdkafka`-union concern that justified this pattern in the Avro
era **no longer applies** with Protobuf (`oneof` works on all
Confluent clients), but the schema-explosion reason still drives the
choice.

## Producer side

1. Serialise the concrete event using its Protobuf message.
2. Build the envelope with:
   * `event_id`     = UUIDv7
   * `event_type`   = the discriminator (e.g. `user_created`)
   * `aggregate_type`, `aggregate_id` = from the outbox table
   * `occurred_at`  = `Timestamp.now()` (Google's well-known type)
   * `schema_version` = 1 (or the schema's major version)
   * `payload_schema` = fully-qualified message name (e.g.
     `me.tinkle.events.user.v1.UserCreatedEvent`)
   * `traceparent`  = current span's traceparent, or `""` if none
   * `producer`     = the producing service name
   * `payload`      = the Protobuf-encoded concrete event
3. Set the **Kafka key** to `aggregate_id` (string). This guarantees
   per-aggregate ordering.
4. Set the **Kafka value** to the Protobuf-encoded envelope.

## Consumer side

1. Decode the envelope using its schema (subject: `<topic>-value`).
2. Read `event_type` and `payload_schema`.
3. Fetch the concrete schema from Schema Registry (by name) and use it
   to decode `payload` (which is `bytes`).
4. Dispatch to a handler keyed by `event_type`.
5. Use `event_id` for **idempotency**: if a duplicate is detected,
   drop it.

## Idempotency

The `event_id` is a UUIDv7 (time-sortable). Consumers SHOULD keep a
short-lived LRU cache of recently-seen `event_id`s (TTL ≥ max
replay-window) to drop duplicates from at-least-once Kafka delivery.
The UUIDv7 format embeds the creation time, so deduplication windows
can be enforced by time as well as by exact match.
