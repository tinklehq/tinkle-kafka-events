# tinkle-kafka-events/schemas/user

Avro event schemas for the user-service CDC topic.

| Kafka topic         | Aggregate | Event type discriminator | Schema                                       |
| ------------------- | --------- | ------------------------ | -------------------------------------------- |
| `outbox.user.event` | `event`   | `user_created`           | `user_created.avsc` (`UserCreatedEvent`)       |
| `outbox.user.event` | `event`   | `user_soft_deleted`      | `user_soft_deleted.avsc` (`UserSoftDeletedEvent`) |
| `outbox.user.event` | `event`   | `user_deleted`           | `user_deleted.avsc` (`UserDeletedEvent`)       |

All schemas share the namespace `io.tinklehq.events.user.v1`.
