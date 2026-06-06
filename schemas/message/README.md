# tinkle-kafka-events/schemas/message

Avro event schemas for chatroom **message** lifecycle (NOT the chat
aggregate itself — see [`schemas/chat`](../chat) for that).

| Aggregate | Event type discriminator | Schema                                       |
| --------- | ------------------------ | -------------------------------------------- |
| `event`   | `message_created`        | `message_created.avsc` (`MessageCreatedEvent`) |
| `event`   | `message_deleted`        | `message_deleted.avsc` (`MessageDeletedEvent`) |
| `event`   | `message_revoked`        | `message_revoked.avsc` (`MessageRevokedEvent`) |

All schemas share the namespace `io.tinklehq.events.message.v1`.
