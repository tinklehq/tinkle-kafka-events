# tinkle-kafka-events/schemas/peer

CDC events produced by `tinklehq/tinkle-server` `chat-service` for the
peer-to-peer block list.

| Kafka topic          | Aggregate | Event type discriminator | Schema                                  |
| -------------------- | --------- | ------------------------ | --------------------------------------- |
| `outbox.peer.event`  | `event`   | `peer_blocked`           | `peer_user_blocked.avsc` (`PeerUserBlockedEvent`)   |
| `outbox.peer.event`  | `event`   | `peer_unblocked`         | `peer_user_unblocked.avsc` (`PeerUserUnblockedEvent`) |

All schemas share the namespace `io.tinklehq.events.peer.v1`.

The Protobuf mirror is in `proto/internal/outbox/v1/outbox.proto`
(`PeerUserBlockedEvent`, `PeerUserUnblockedEvent`).
