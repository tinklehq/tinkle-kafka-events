# tinkle-kafka-events/schemas

This directory tree holds every Avro schema for Tinkle Messenger's
internal Kafka CDC events. One record per `.avsc` file. Namespaces
follow the convention `io.tinklehq.events.<service>.v1`.

| Directory  | Topic(s)                                            |
| ---------- | --------------------------------------------------- |
| `common/`  | (shared types — see `common/README.md`)             |
| `user/`    | `outbox.user.event`                                 |
| `chat/`    | `outbox.chat.event`                                 |
| `roster/`  | `outbox.roster.event`                               |
| `peer/`    | `outbox.peer.event`                                 |
| `privacy/` | `outbox.privacy.<kind>` (6 kinds x 3 ops = 18)      |
| `message/` | `outbox.message.event`                              |
| `muc/`     | `outbox.muc.message`                                |
| `bot/`     | `outbox.bot.event`                                  |

See each subdirectory's `README.md` for the per-event type
discriminator and the schema that defines it.

> **Every** Kafka value published to one of these topics is wrapped
> in the standard `Envelope` record defined in
> [`common/envelope.avsc`](common/envelope.avsc). See
> [`../docs/envelope.md`](../docs/envelope.md) for the producer and
> consumer flow.
