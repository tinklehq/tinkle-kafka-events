# tinkle-kafka-events/schemas/user

CDC events produced by `tinklehq/tinkle-server` `user-service`.

| Kafka topic         | Aggregate | Event type discriminator | Schema                                  |
| ------------------- | --------- | ------------------------ | --------------------------------------- |
| `outbox.user.event` | `event`   | `user_created`           | `user_created.avsc` (`UserCreatedEvent`)  |
| `outbox.user.event` | `event`   | `user_soft_deleted`      | `user_soft_deleted.avsc` (`UserSoftDeletedEvent`) |
| `outbox.user.event` | `event`   | `user_deleted`           | `user_deleted.avsc` (`UserDeletedEvent`)  |

All schemas share the namespace `io.tinklehq.events.user.v1`.

The Go-side constants that map to these discriminators are defined in
`src/libs/cdcevent/cdcevent.go` in `tinklehq/tinkle-server`:

```go
UserCreated     = "user_created"
UserSoftDeleted = "user_soft_deleted"
UserDeleted     = "user_deleted"
```

The Protobuf mirror is `proto/internal/outbox/v1/outbox.proto` messages
`UserCreatedEvent` and `UserDeletedEvent`. This Avro repo is the
authoritative wire contract for non-Go consumers.
