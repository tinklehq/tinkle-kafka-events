# tinkle-kafka-events/schemas/bot

CDC events produced by `tinklehq/tinkle-server` `bot-service`.

| Kafka topic         | Aggregate | Event type discriminator | Schema                                            |
| ------------------- | --------- | ------------------------ | ------------------------------------------------- |
| `outbox.bot.event`  | `event`   | `bot_message_created`    | `bot_message_created.avsc` (`BotMessageCreatedEvent`) |
| `outbox.bot.event`  | `event`   | `bot_message_edited`     | `bot_message_edited.avsc` (`BotMessageEditedEvent`)   |
| `outbox.bot.event`  | `event`   | `bot_message_deleted`    | `bot_message_deleted.avsc` (`BotMessageDeletedEvent`) |
| `outbox.bot.event`  | `event`   | `bot_callback_query`     | `bot_callback_query.avsc` (`BotCallbackQueryEvent`)   |

All schemas share the namespace `io.tinklehq.events.bot.v1`.

The Go-side constants are in `src/libs/cdcevent/cdcevent.go`:

```go
BotAggregateType = "event"

BotMessageCreated = "bot_message_created"
BotMessageEdited  = "bot_message_edited"
BotMessageDeleted = "bot_message_deleted"
BotCallbackQuery  = "bot_callback_query"
```

The Protobuf mirror is in `proto/internal/bot/v1/bot.proto`
(`BotSendMessageOutboxEvent` — the most-frequently-produced event;
`BotMessageEditedEvent`, `BotMessageDeletedEvent`, and
`BotCallbackQueryEvent` are TODO and are defined as Go domain structs
in `src/services/bot/internal/domain/events.go`).
