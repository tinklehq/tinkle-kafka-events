# tinkle-kafka-events/schemas/peer

Avro event schemas for the chat-service peer-block CDC topic.

| Kafka topic          | Aggregate | Event type discriminator | Schema                                       |
| -------------------- | --------- | ------------------------ | -------------------------------------------- |
| `outbox.peer.event`  | `event`   | `peer_blocked`           | `peer_user_blocked.avsc` (`PeerUserBlockedEvent`)   |
| `outbox.peer.event`  | `event`   | `peer_unblocked`         | `peer_user_unblocked.avsc` (`PeerUserUnblockedEvent`) |

All schemas share the namespace `me.tinkle.events.peer.v1`.
