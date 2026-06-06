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

## Operational workflows

### Adding a new event type to an existing topic

1. Add the new `.avsc` under the appropriate `schemas/<service>/`
   directory.
2. Run `./scripts/validate.sh` locally to confirm it parses.
3. Open a PR. CI registers the candidate schema against the staging
   Schema Registry; if it's incompatible with the latest version the
   PR fails.

### Adding a new topic

1. Pick a topic name (e.g. `outbox.<service>.<aggregate>`).
2. Author the per-event `.avsc` files under a new
   `schemas/<service>/` directory.
3. Register the Envelope schema under `<topic>-value` in the
   registry. This will auto-create the subject.
4. Update producer and consumer code to use the new topic.

### Bumping an event to a breaking new version

1. Bump the schema's namespace to `v2`:
   `io.tinklehq.events.user.v2.UserCreatedEvent`.
2. Register it under the **same subject** as v1
   (`outbox.user.event-value`); Schema Registry will store both
   versions.
3. Producers dual-write to **both** `v1` and `v2` for one release
   window.
4. Consumers migrate to `v2`.
5. Producers stop dual-writing.
6. The `v1` subject is **frozen** (still readable by old consumers for
   replay), but not evolved further.
7. After a defined grace period (typically one quarter), the `v1`
   version of the subject is marked `deleted: true` in the registry.
