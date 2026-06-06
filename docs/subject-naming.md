# Subject naming

> How this repo maps Kafka topics to Schema Registry subjects.

## Strategy

This repo uses the **TopicNameStrategy** — Confluent's recommended
default — which derives the subject from the topic name:

```
subject = <topic>-value      // for message values
subject = <topic>-key        // for message keys (we use STRING keys, not schema'd)
```

### Why not the `RecordNameStrategy`?

`RecordNameStrategy` derives the subject from the **fully-qualified
record name**. With our envelope pattern, every topic would share the
subject `io.tinklehq.events.common.v1.Envelope-value` — which means
**every topic's schema would be in the same subject, and any change
would be compared against every other topic's payload**. That's an
operational nightmare.

TopicNameStrategy gives us a per-topic subject, which matches our
operational reality: one team owns one topic, one team is responsible
for its compatibility.

## Concrete subject -> schema mapping

| Topic                       | Subject                       | Schemas (current)                                                                 |
| --------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| `outbox.user.event`         | `outbox.user.event-value`     | `io.tinklehq.events.common.v1.Envelope` (record wraps the concrete event)        |
| `outbox.chat.event`         | `outbox.chat.event-value`     | `Envelope`                                                                        |
| `outbox.roster.event`       | `outbox.roster.event-value`   | `Envelope`                                                                        |
| `outbox.peer.event`         | `outbox.peer.event-value`     | `Envelope`                                                                        |
| `outbox.privacy.call`       | `outbox.privacy.call-value`   | `Envelope`                                                                        |
| `outbox.privacy.presence`   | `outbox.privacy.presence-value` | `Envelope`                                                                      |
| `outbox.privacy.phone_number` | `outbox.privacy.phone_number-value` | `Envelope`                                                                  |
| `outbox.privacy.about`      | `outbox.privacy.about-value`  | `Envelope`                                                                        |
| `outbox.privacy.profile_photo` | `outbox.privacy.profile_photo-value` | `Envelope`                                                                  |
| `outbox.privacy.chat_invite` | `outbox.privacy.chat_invite-value` | `Envelope`                                                                    |
| `outbox.muc.message`        | `outbox.muc.message-value`    | `Envelope`                                                                        |
| `outbox.bot.event`          | `outbox.bot.event-value`      | `Envelope`                                                                        |

The **concrete event schemas** (`UserCreatedEvent`, `RosterContactAddedEvent`,
...) are registered as **referenced** schemas — they are uploaded
alongside the Envelope, but live under their own FQN subject so they
can be looked up by record name from any consumer.

## How a consumer finds the right schema

1. Receive a message from `<topic>`.
2. Read the magic byte + schema-ID prefix to get the Envelope schema
   (which is always the latest version of `<topic>-value`).
3. Decode the Envelope. Read `payload_schema`
   (e.g. `io.tinklehq.events.user.v1.UserCreatedEvent`).
4. Look up the Schema Registry subject for that FQN (e.g.
   `io.tinklehq.events.user.v1.UserCreatedEvent`).
5. Fetch the latest version of that subject and decode `payload`.

Step 4 is what makes the envelope pattern robust against union
encoding: consumers never need to know the union, they just look up
by name.

## Migration paths

### From Protobuf to Avro

The existing `outbox.user.event` topic is currently populated with
JSONB envelopes wrapping base64-encoded Protobuf messages:

```json
{ "event_type": "user_created", "data": "CAEQAQ==", "traceparent": "..." }
```

When migrating to Avro:

1. Register the Envelope schema against `outbox.user.event-value` in
   the staging registry.
2. Dual-write producers emit BOTH the Protobuf (existing code path) AND
   the Avro envelope (new code path), discriminated by a magic byte in
   a Kafka header.
3. Consumers learn to detect the magic byte and dispatch.
4. Once all consumers are migrated, remove the Protobuf code path.
5. Subject history is preserved — old Protobuf events remain readable
   for any consumer that needs to backfill.

### Adding a new topic

1. Author the Envelope usage in this repo (most are already in place).
2. Author any **new** event schemas in the appropriate
   `schemas/<service>/` directory.
3. Register the Envelope schema under `<topic>-value` in the
   registry. This will auto-create the subject.
4. Update `cdcevent` topic constants in
   `tinklehq/tinkle-server/src/libs/cdcevent/cdcevent.go` to point
   to the new topic.
5. Update producer code to use the new envelope-based helper.
