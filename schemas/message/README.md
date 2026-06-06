# tinkle-kafka-events/schemas/message

CDC events for chatroom **message** lifecycle (NOT the chat aggregate
itself — see [`schemas/chat`](../chat) for that).

| Aggregate | Event type discriminator | Schema                                  |
| --------- | ------------------------ | --------------------------------------- |
| `event`   | `message_created`        | `message_created.avsc` (`MessageCreatedEvent`) |
| `event`   | `message_deleted`        | `message_deleted.avsc` (`MessageDeletedEvent`) |
| `event`   | `message_revoked`        | `message_revoked.avsc` (`MessageRevokedEvent`) |

All schemas share the namespace `io.tinklehq.events.message.v1`.

The Protobuf mirror is in `proto/internal/outbox/v1/outbox.proto`
(`MessageCreatedEvent`, `MessageDeletedEvent`, `MessageRevokedEvent`).
The Go-side constants are added in a follow-up to
`src/libs/cdcevent/cdcevent.go` (currently only Protobuf consumers
exist for these events).
