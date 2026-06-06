# Envelope pattern

> Why every event in this repo is wrapped in a standard `Envelope`
> record before it hits Kafka.

## Definition

[`schemas/common/envelope.avsc`](../schemas/common/envelope.avsc):

```jsonc
{
  "type": "record",
  "name": "Envelope",
  "namespace": "io.tinklehq.events.common.v1",
  "fields": [
    { "name": "event_id",       "type": "string"  },
    { "name": "event_type",     "type": "string"  },
    { "name": "aggregate_type", "type": "string"  },
    { "name": "aggregate_id",   "type": "string"  },
    { "name": "occurred_at",    "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "schema_version", "type": "int"     },
    { "name": "payload_schema", "type": "string"  },
    { "name": "traceparent",    "type": ["null", "string"], "default": null },
    { "name": "producer",       "type": ["null", "string"], "default": null },
    { "name": "payload",        "type": "bytes"   }
  ]
}
```

## Why an envelope?

A bare `UserCreatedEvent` on the wire is a perfectly valid Kafka
message, but it leaks responsibility onto the consumer: every consumer
must know the topic, guess at the schema version, parse a W3C
traceparent from a header, and so on.

The envelope is a deliberate separation of **routing concerns** from
**domain concerns**:

| Concern                       | Lives in envelope? | Lives in payload? |
| ----------------------------- | ------------------ | ----------------- |
| Trace propagation             | yes `traceparent`  |                  |
| Idempotency key               | yes `event_id`     |                  |
| Routing (Kafka key)           | yes `aggregate_id` |                  |
| Producer attribution          | yes `producer`     |                  |
| Schema-Registry lookup hint   | yes `payload_schema`|                 |
| Wire compat for the event itself |               | yes domain fields |

This pattern is endorsed by CloudEvents, CNCF's Serverless Working
Group, and most large Kafka shops (LinkedIn, Confluent, Uber).

## Why a generic `bytes` payload (not a union)?

A cleaner envelope would put the payload as a union of every concrete
event type:

```jsonc
{ "name": "payload", "type": [
  "io.tinklehq.events.user.v1.UserCreatedEvent",
  "io.tinklehq.events.user.v1.UserDeletedEvent",
  "io.tinklehq.events.chat.v1.ChatCreatedEvent",
  ...
] }
```

We deliberately don't do that, for two reasons:

1. **librdkafka / non-JVM client compatibility.** librdkafka (used by
   most non-Java clients, including `confluent-kafka-go`, `node-rdkafka`,
   `python-confluent-kafka`) does **not** support Avro unions in
   deserialisation. See the [Confluent docs](https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/serdes-avro.html#limitations-for-librdkafka-clients).

2. **Schema-explosion.** Every new event type would force the
   envelope's union to grow, creating a new envelope schema version —
   which is a no-go for an event that should be stable for years.

The `bytes` + `payload_schema` approach is the
[librdkafka-compatible workaround](https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/serdes-avro.html#limitations-for-librdkafka-clients)
that the Confluent docs themselves recommend for this case.

## Producer side

1. Serialise the concrete event using its Avro schema.
2. Build the envelope with:
   * `event_id`     = UUIDv7
   * `event_type`   = the discriminator (e.g. `user_created`)
   * `aggregate_type`, `aggregate_id` = from the outbox table
   * `occurred_at`  = now()
   * `schema_version` = 1 (or the schema's major version)
   * `payload_schema` = fully-qualified record name (e.g. `io.tinklehq.events.user.v1.UserCreatedEvent`)
   * `traceparent`  = current span's traceparent, if any
   * `producer`     = the producing service name
   * `payload`      = the Avro-encoded concrete event
3. Set the **Kafka key** to `aggregate_id` (string). This guarantees
   per-aggregate ordering.
4. Set the **Kafka value** to the Avro-encoded envelope.

## Consumer side

1. Decode the envelope using its schema (subject:
   `<topic>-value`).
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
