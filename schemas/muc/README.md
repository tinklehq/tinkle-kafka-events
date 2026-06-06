# tinkle-kafka-events/schemas/muc

Avro event schemas for the muc-to-bot routing CDC topic. Events signal
a downstream bot that a new message has been addressed to it.

| Kafka topic            | Aggregate | Event type discriminator | Schema                                  |
| ---------------------- | --------- | ------------------------ | --------------------------------------- |
| `outbox.muc.message`   | `message` | `message_to_bot`         | `message_to_bot.avsc` (`MessageToBotEvent`) |

All schemas share the namespace `me.tinkle.events.muc.v1`.

> **Why a dedicated topic?** Routing messages-to-bots to a separate
> topic keeps the bot-service consumer decoupled from the high-volume
> general chat-event stream and lets the bot-service scale
> independently.
