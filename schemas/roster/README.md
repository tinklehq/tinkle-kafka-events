# tinkle-kafka-events/schemas/roster

CDC events produced by `tinklehq/tinkle-server` `roster-service`.

| Kafka topic           | Aggregate | Event type discriminator         | Schema                                                                |
| --------------------- | --------- | -------------------------------- | --------------------------------------------------------------------- |
| `outbox.roster.event` | `event`   | `roster_contact_added`           | `roster_contact_added.avsc` (`RosterContactAddedEvent`)               |
| `outbox.roster.event` | `event`   | `roster_contact_deleted`         | `roster_contact_deleted.avsc` (`RosterContactDeletedEvent`)           |
| `outbox.roster.event` | `event`   | `roster_cleared`                 | `roster_cleared.avsc` (`RosterClearedEvent`)                          |
| `outbox.roster.event` | `event`   | `roster_contact_batch_added`     | `roster_contact_batch_added.avsc` (`RosterContactBatchAddedEvent`)    |
| `outbox.roster.event` | `event`   | `roster_contact_batch_deleted`   | `roster_contact_batch_deleted.avsc` (`RosterContactBatchDeletedEvent`)|
| `outbox.roster.event` | `event`   | `roster_mutual_contact_established` | `mutual_contact_established.avsc` (`MutualContactEstablishedEvent`) |
| `outbox.roster.event` | `event`   | `roster_mutual_contact_broken`   | `mutual_contact_broken.avsc` (`MutualContactBrokenEvent`)             |

All schemas share the namespace `io.tinklehq.events.roster.v1`.

The Protobuf mirror is in two files:
* `proto/internal/outbox/v1/outbox.proto` — `RosterContactAddedEvent`,
  `RosterContactDeletedEvent`, `RosterClearedEvent`,
  `RosterContactBatchAddedEvent`, `RosterContactBatchDeletedEvent`.
* `proto/internal/roster/v1/roster.proto` — `MutualContactEstablishedEvent`,
  `MutualContactBrokenEvent`.

The Go-side constants are in
`src/libs/cdcevent/cdcevent.go`:

```go
RosterContactAdded             = "roster_contact_added"
RosterContactDeleted           = "roster_contact_deleted"
RosterCleared                  = "roster_cleared"
RosterContactBatchAdded        = "roster_contact_batch_added"
RosterContactBatchDeleted      = "roster_contact_batch_deleted"
RosterMutualContactEstablished = "roster_mutual_contact_established"
RosterMutualContactBroken      = "roster_mutual_contact_broken"
```
