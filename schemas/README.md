# tinkle-kafka-events/schemas

This directory tree holds every Avro schema for Tinkle Messenger's
internal Kafka CDC events. One record per `.avsc` file. Namespaces
follow the convention `io.tinklehq.events.<service>.v1`.

| Directory  | Producer service          | Topic(s)                                            |
| ---------- | ------------------------- | --------------------------------------------------- |
| `common/`  | (shared)                  | n/a                                                 |
| `user/`    | user-service              | `outbox.user.event`                                 |
| `chat/`    | chat-service (MUC)        | `outbox.chat.event`                                 |
| `roster/`  | roster-service            | `outbox.roster.event`                               |
| `peer/`    | chat-service (peer block) | `outbox.peer.event`                                 |
| `privacy/` | privacy-service           | `outbox.privacy.<kind>` (6 kinds x 3 ops = 18)      |
| `message/` | chat-service (msg lifecycle) | (no topic yet — planned)                        |
| `muc/`     | muc-service (bot routing) | `outbox.muc.message`                                |
| `bot/`     | bot-service               | `outbox.bot.event`                                  |

See each subdirectory's `README.md` for the per-event type
discriminator and Go-side constant mapping.

> **Every** Kafka value published to one of these topics is wrapped
> in the standard `Envelope` record defined in
> [`common/envelope.avsc`](common/envelope.avsc). See
> [`../docs/envelope.md`](../docs/envelope.md) for the producer and
> consumer flow.
