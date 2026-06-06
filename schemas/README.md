# tinkle-kafka-events/schemas

This directory tree holds every Avro schema for Tinkle Messenger's
internal Kafka CDC events. One record per `.avsc` file. Namespaces
follow the convention `io.tinklehq.events.<service>.v1`.

| Directory  | Topic(s)                                            |
| ---------- | --------------------------------------------------- |
| `common/`  | (shared types — see `common/README.md`)             |
| `user/`    | `outbox.user.event`                                 |
| `chat/`    | `outbox.chat.event`                                 |
| `roster/`  | `outbox.roster.event`                               |
| `peer/`    | `outbox.peer.event`                                 |
| `privacy/` | `outbox.privacy.<kind>` (6 kinds x 3 ops = 18)      |
| `message/` | `outbox.message.event`                              |
| `muc/`     | `outbox.muc.message`                                |
| `bot/`     | `outbox.bot.event`                                  |

See each subdirectory's `README.md` for the per-event type
discriminator and the schema that defines it.

> **Every** Kafka value published to one of these topics is wrapped
> in the standard `Envelope` record defined in
> [`common/envelope.avsc`](common/envelope.avsc). See
> [`../docs/envelope.md`](../docs/envelope.md) for the producer and
> consumer flow.

## Conventions

These rules apply to every `.avsc` file in this tree. New schemas
MUST follow them; changes that drift from them are a CI failure.

### Parsing Canonical Form (PCF) attribute order

Every record and enum declares its top-level keys in PCF order
(per the Avro spec, §1): `name` first, then `type`, then any
non-PCF attributes (`namespace`, `doc`, `aliases`), and finally
the list attribute (`fields` for records, `symbols` for enums).
Reordering the keys does not change validity but does change the
**schema fingerprint**, so consistent ordering keeps diffs and
fingerprints stable across the repo.

Fields inside `fields: [...]` are also PCF-ordered: `name`, `type`,
then `doc` and (when present) `default`. Every field in this repo
follows that pattern.

### Namespaces and FQNs

- Every record and enum has a `namespace` of the form
  `io.tinklehq.events.<service>.v<N>`.
- The shared privacy enums
  ([`PrivacyAllowValue`](common/enums.avsc),
  [`PrivacyRuleAction`](common/enums_privacy_action.avsc))
  intentionally live under `schemas/common/` but use the
  `io.tinklehq.events.privacy.v1` namespace, so that other schemas
  can reference them without a circular import. The `doc` field on
  each enum explains this.
- All identifiers (`name`, `namespace`, field names) are
  `snake_case`. Enum symbols are `SCREAMING_SNAKE_CASE` and start
  with a `*_UNSPECIFIED` zero value.

### Documentation coverage

Every record, enum, and field has a `doc` attribute. The `doc`
should describe the **semantics** (what the value means, who
produces it, what consumers should do with it) — not just
paraphrase the name. PRs that add a schema or field without a
`doc` are rejected.

### Timestamps

Two places a timestamp can live:

1. **The envelope**, at
   [`common/envelope.avsc`](common/envelope.avsc): the `occurred_at`
   field (`timestamp-millis`) is the wall-clock instant the event
   was produced. Every event has one.
2. **The payload**, as a `timestamp-millis` logical type field
   named `created_at`, `deleted_at`, `edited_at`, `revoked_at`,
   etc. Only present when the payload has a *domain* timestamp
   that differs from when the event was published.

Events that mutate a record (create / edit / delete / revoke)
carry the domain timestamp in the payload. Events whose only
effect is metadata routing (privacy rule changes, soft-delete
markers, `BotMessageDeletedEvent`, `MessageDeletedEvent`,
`MessageRevokedEvent`, `UserSoftDeletedEvent`) intentionally
**do not** duplicate the timestamp; consumers should use the
envelope's `occurred_at`.

### Forward compatibility for new fields

When you add a field to an existing schema, you MUST give it a
`default`. A field with no `default` is "required" — adding it
breaks any older consumer that hasn't been redeployed with the
new schema. Nullable fields should use the pattern:

```jsonc
{ "name": "country_code", "type": ["null", "string"], "default": null }
```

Full evolution rules (renames, enum symbols, type promotions,
the deprecation dance) are in
[`../docs/compatibility.md`](../docs/compatibility.md). The CI
workflow `.github/workflows/schema-compatibility.yml` enforces
`BACKWARD` compatibility at PR time.

### Discriminator-tag pattern (`message_type: string`)

`bot_message_created`, `bot_message_edited`, and
`message_to_bot` carry a `message_type: string` field whose
value is a kind tag (`'text'`, `'photo'`, `'document'`,
`'voice'`, `'video'`, `'sticker'`) for the inner `payload: bytes`
blob. The blob's encoding is **not** described by the
surrounding event schema — it's an opaque, content-type-tagged
payload, dispatched by the consumer. The envelope's
`payload_schema` field names the **outer** schema (e.g.
`BotMessageCreatedEvent`), not the inner one. This keeps the
outer schema stable as inner payload formats evolve
independently.
