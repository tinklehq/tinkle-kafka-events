# tinkle-kafka-events/schemas/muc

CDC events produced by `tinklehq/tinkle-server` `muc-service` for
**muc-to-bot routing** — i.e. events that signal a downstream bot that
a new message has been addressed to it.

| Kafka topic            | Aggregate | Event type discriminator | Schema                                  |
| ---------------------- | --------- | ------------------------ | --------------------------------------- |
| `outbox.muc.message`   | `message` | `message_to_bot`         | `message_to_bot.avsc` (`MessageToBotEvent`) |

All schemas share the namespace `io.tinklehq.events.muc.v1`.

> **Why a dedicated topic?** Routing messages-to-bots to a separate
> topic keeps the bot-service consumer decoupled from the high-volume
> general chat-event stream and lets the bot-service scale
> independently.

The Go-side constant is in `src/libs/cdcevent/cdcevent.go`:

```go
MucMessageAggregateType = "message"
MessageToBot            = "message_to_bot"
```

The Protobuf mirror is still TODO in the Go service (the bot-service
in-memory domain struct `InboundBotMessagePayload` is defined in
`src/services/bot/internal/domain/events.go`).
