# Subject naming

> How this repo maps Kafka topics to Confluent Schema Registry
> subjects.

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
subject `me.tinkle.events.common.v1.Envelope-value` — which means
**every topic's schema would be in the same subject, and any change
would be compared against every other topic's payload**. That's an
operational nightmare.

TopicNameStrategy gives us a per-topic subject, which matches our
operational reality: one team owns one topic, one team is responsible
for its compatibility.

### Why not `TopicRecordNameStrategy`?

`TopicRecordNameStrategy` gives one subject per `(topic, record)`
pair, which is closer to the `oneof`-payload model. We deliberately
don't use a `oneof` payload (see [`envelope.md`](envelope.md)), so the
extra dimension is unnecessary.

## Concrete subject → schema mapping

| Topic                       | Subject                       | Schemas (current)                                                                 |
| --------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| `outbox.user.event`         | `outbox.user.event-value`     | `me.tinkle.events.common.v1.Envelope` (record wraps the concrete event)          |
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
...) are registered alongside the Envelope under the same subject
(the Envelope's `.proto` text references each concrete message via
the `payload_schema` string at runtime, but the SR subject itself is
per-topic). The concrete schemas are also registered individually
under their FQN-derived subject so they can be looked up by name from
any consumer (the same way as the Avro era).

## How a consumer finds the right schema

1. Receive a message from `<topic>`.
2. Read the magic byte + schema-ID prefix to get the Envelope schema
   (which is always the latest version of `<topic>-value`).
3. Decode the Envelope. Read `payload_schema`
   (e.g. `me.tinkle.events.user.v1.UserCreatedEvent`).
4. Look up the Schema Registry subject for that FQN (e.g.
   `me.tinkle.events.user.v1.UserCreatedEvent`).
5. Fetch the latest version of that subject and decode `payload`.

Step 4 is what makes the envelope pattern robust against `oneof`
encoding: consumers never need to know the `oneof` variants, they
just look up by name.

## Operational workflows

### Adding a new event type to an existing topic

1. Add the new `.proto` under the appropriate
   `proto/<service>/v1/` directory.
2. Run `buf format -w` and `buf lint` locally to confirm it parses
   and is style-clean.
3. Open a PR. CI runs `buf lint`, `buf breaking`; if the new schema
   is wire-incompatible with the latest version, the PR fails.

### Adding a new topic

1. Pick a topic name (e.g. `outbox.<service>.<aggregate>`).
2. Author the per-event `.proto` files under a new
   `proto/<service>/v1/` directory.
3. Merge to `main`; the BSR push from CI publishes the new schema.
   The deploy pipeline syncs the BSR-published schema into the
   Confluent SR subject `<topic>-value` and auto-creates the
   subject.
4. Update producer and consumer code to use the new topic.

### Bumping an event to a breaking new version

1. Bump the schema's package to `v2`:
   `me.tinkle.events.user.v2.UserCreatedEvent`.
2. Create a sibling directory `proto/user/v2/user_created.proto`.
3. Open a PR with the `buf skip breaking` label (the directory
   rename is a structural change that `buf breaking` flags as
   "files moved", which is not a wire-compat break — but `buf
   breaking` can't tell the difference).
4. Merge to `main`; the BSR push from CI publishes the new
   `me.tinkle.events.user.v2` schema as a new module commit.
5. The deploy pipeline registers the new schema under the **same
   subject** as v1 (`outbox.user.event-value`); Confluent SR will
   store both versions of the FileDescriptor.
6. Producers dual-write to **both** `v1` and `v2` for one release
   window.
7. Consumers migrate to `v2`.
8. Producers stop dual-writing.
9. The `v1` package is **frozen** (still readable by old consumers
   for replay), but not evolved further.
10. After a defined grace period (typically one quarter), the `v1`
    version of the subject is marked `deleted: true` in the
    registry.
