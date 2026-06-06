# tinkle-kafka-events/schemas/bot

Avro event schemas for the bot-service CDC topic.

| Kafka topic         | Aggregate | Event type discriminator | Schema                                                  |
| ------------------- | --------- | ------------------------ | ------------------------------------------------------- |
| `outbox.bot.event`  | `event`   | `bot_message_created`    | `bot_message_created.avsc` (`BotMessageCreatedEvent`)   |
| `outbox.bot.event`  | `event`   | `bot_message_edited`     | `bot_message_edited.avsc` (`BotMessageEditedEvent`)     |
| `outbox.bot.event`  | `event`   | `bot_message_deleted`    | `bot_message_deleted.avsc` (`BotMessageDeletedEvent`)   |
| `outbox.bot.event`  | `event`   | `bot_callback_query`     | `bot_callback_query.avsc` (`BotCallbackQueryEvent`)     |

All schemas share the namespace `io.tinklehq.events.bot.v1`.
