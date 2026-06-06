# tinkle-kafka-events/schemas/chat

CDC events produced by `tinklehq/tinkle-server` `chat-service` (MUC
back-end) for chat lifecycle management.

| Kafka topic         | Aggregate | Event type discriminator | Schema                                |
| ------------------- | --------- | ------------------------ | ------------------------------------- |
| `outbox.chat.event` | `event`   | `chat_created`           | `chat_created.avsc` (`ChatCreatedEvent`) |
| `outbox.chat.event` | `event`   | `chat_deleted`           | `chat_deleted.avsc` (`ChatDeletedEvent`) |

All schemas share the namespace `io.tinklehq.events.chat.v1`.

> **Note:** Chatroom **message** events (create / delete / revoke) live
> in `schemas/message/`. The chat subdirectory here is reserved for the
> chat *aggregate* lifecycle (the chat room itself, not its messages).
