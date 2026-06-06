# tinkle-kafka-events/schemas/roster

Avro event schemas for the roster-service CDC topic.

| Kafka topic           | Aggregate | Event type discriminator             | Schema                                                                |
| --------------------- | --------- | ------------------------------------ | --------------------------------------------------------------------- |
| `outbox.roster.event` | `event`   | `roster_contact_added`               | `roster_contact_added.avsc` (`RosterContactAddedEvent`)               |
| `outbox.roster.event` | `event`   | `roster_contact_deleted`             | `roster_contact_deleted.avsc` (`RosterContactDeletedEvent`)           |
| `outbox.roster.event` | `event`   | `roster_cleared`                     | `roster_cleared.avsc` (`RosterClearedEvent`)                          |
| `outbox.roster.event` | `event`   | `roster_contact_batch_added`         | `roster_contact_batch_added.avsc` (`RosterContactBatchAddedEvent`)    |
| `outbox.roster.event` | `event`   | `roster_contact_batch_deleted`       | `roster_contact_batch_deleted.avsc` (`RosterContactBatchDeletedEvent`)|
| `outbox.roster.event` | `event`   | `roster_mutual_contact_established`  | `mutual_contact_established.avsc` (`MutualContactEstablishedEvent`)   |
| `outbox.roster.event` | `event`   | `roster_mutual_contact_broken`       | `mutual_contact_broken.avsc` (`MutualContactBrokenEvent`)             |

All schemas share the namespace `io.tinklehq.events.roster.v1`.
