# tinkle-kafka-events/schemas/privacy

CDC events produced by `tinklehq/tinkle-server` `privacy-service`.

Privacy events follow a **per-kind topic** topology: each privacy kind
(call, presence, phone_number, about, profile_photo, chat_invite) gets
its own Kafka topic and its own outbox table. This is the most
high-volume CDC stream in the system — splitting by kind lets consumers
subscribe to only the kinds they care about.

| Privacy kind      | Kafka topic                       | Aggregate       | Operations                | Schemas (per op)                                                                              |
| ----------------- | --------------------------------- | --------------- | ------------------------- | --------------------------------------------------------------------------------------------- |
| `call`            | `outbox.privacy.call`             | `call`          | upsert / upsert_rule / remove_rule | `upsert_call_privacy.avsc`, `upsert_call_privacy_rule.avsc`, `remove_call_privacy_rule.avsc`   |
| `presence`        | `outbox.privacy.presence`         | `presence`      | upsert / upsert_rule / remove_rule | `upsert_presence_privacy.avsc`, `upsert_presence_privacy_rule.avsc`, `remove_presence_privacy_rule.avsc` |
| `phone_number`    | `outbox.privacy.phone_number`     | `phone_number`  | upsert / upsert_rule / remove_rule | `upsert_phone_number_privacy.avsc`, `upsert_phone_number_privacy_rule.avsc`, `remove_phone_number_privacy_rule.avsc` |
| `about`           | `outbox.privacy.about`            | `about`         | upsert / upsert_rule / remove_rule | `upsert_about_privacy.avsc`, `upsert_about_privacy_rule.avsc`, `remove_about_privacy_rule.avsc` |
| `profile_photo`   | `outbox.privacy.profile_photo`    | `profile_photo` | upsert / upsert_rule / remove_rule | `upsert_profile_photo_privacy.avsc`, `upsert_profile_photo_privacy_rule.avsc`, `remove_profile_photo_privacy_rule.avsc` |
| `chat_invite`     | `outbox.privacy.chat_invite`      | `chat_invite`   | upsert / upsert_rule / remove_rule | `upsert_chat_invite_privacy.avsc`, `upsert_chat_invite_privacy_rule.avsc`, `remove_chat_invite_privacy_rule.avsc` |

All schemas share the namespace `io.tinklehq.events.privacy.v1`. The
shared `PrivacyAllowValue` and `PrivacyRuleAction` enums are defined in
[`schemas/common/enums.avsc`](../common/enums.avsc) and
[`schemas/common/enums_privacy_action.avsc`](../common/enums_privacy_action.avsc).

The Protobuf mirror is in `proto/internal/outbox/v1/outbox.proto`
(18 messages, 3 per kind). The Go-side constants are in
`src/libs/cdcevent/cdcevent.go`:

```go
// Per-kind aggregate types
PrivacyAggregateCall         = "call"
PrivacyAggregatePresence     = "presence"
PrivacyAggregatePhoneNumber  = "phone_number"
PrivacyAggregateAbout        = "about"
PrivacyAggregateProfilePhoto = "profile_photo"
PrivacyAggregateChatInvite   = "chat_invite"

// Per-kind event types
PrivacyUpsertCallSetting    = "upsert_call_privacy"
PrivacyUpsertCallRule       = "upsert_call_privacy_rule"
PrivacyRemoveCallRule       = "remove_call_privacy_rule"
// ... and the same triple for the other 5 kinds
```
