# Compatibility policy

> The rules that every schema in this repo MUST follow.

## Modes

Confluent Schema Registry (and compatible registries) supports four
compatibility modes:

| Mode                   | Direction                                  | Use case                                |
| ---------------------- | ------------------------------------------ | --------------------------------------- |
| `BACKWARD`             | New consumer can read old data             | Upgrade **consumers** before producers  |
| `BACKWARD_TRANSITIVE`  | New consumer can read all historical data  | Default for Protobuf (see below)        |
| `FORWARD`              | Old consumer can read new data             | Upgrade **producers** before consumers  |
| `FULL` / `FULL_TRANSITIVE` | Both directions                        | Independent upgrade order               |
| `NONE`                 | No check                                   | Never in production                     |

This repository uses **`BACKWARD_TRANSITIVE`** as the default. The
Confluent Schema Registry
[docs](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html)
recommend this for Protobuf explicitly:

> "Note that best practice for Protobuf is to use
> `BACKWARD_TRANSITIVE`, as adding new message types is not forward
> compatible."

Why we choose `BACKWARD_TRANSITIVE` over plain `BACKWARD`:

* It catches **transitive** breaks across the full subject history,
  not just against the latest version.
* It is the safest default for a growing event catalog.
* The cost of "add a new event type" is negligible in our model
  (consumers dispatch on `payload_schema` and ignore unknown FQNs).

## Rules (Protobuf-specific)

### YES Adding a new field

Always allowed. Proto3 fields are implicitly optional; the zero value
is the de-facto default. Use a **fresh tag number** for the new field.

```proto
string country_code = 7;  // new field, tag 7 was previously unused
```

### YES Removing a field

Allowed, **iff** the field's tag number is added to `reserved`:

```proto
message UserCreatedEvent {
  reserved 3;                 // was phone_number
  reserved "phone_number";    // also block the name
  int64          user_id      = 1;
  google.protobuf.Timestamp created_at = 2;
}
```

`reserved` blocks both the tag and the name from future reuse, so a
later PR can't accidentally re-introduce the field under the same
identity (or a different identity at the same tag).

### YES Marking a field deprecated

Allowed without reservation; the wire format is unchanged.

```proto
string phone_number = 3 [deprecated = true];
```

### YES Adding a new enum value

Allowed. Existing data still decodes (the unknown ordinal is preserved
on the wire). Use a fresh ordinal; do not reorder or renumber existing
values.

### NO Renaming a field

**Not allowed for any consumer that uses a JSON-or-text format
(Connect, gRPC-JSON).** The Protobuf wire encoding uses the tag
number, not the name, so binary-only consumers won't notice; but
Buf's `WIRE_JSON` category and Google's wire-compat checker both flag
the rename. Use `[deprecated = true]` and add the new field with a new
name + new tag instead.

### NO Changing a field's type

**Not allowed**, even for the same-wire-type pairs that Confluent's
checker would technically permit (`int32` ↔ `uint32`, `string` ↔
`bytes`, etc.). We treat all type changes as breaking to keep
consumers predictable across all client SDKs. If a field needs a new
type, add the new field, dual-write for a release, then deprecate the
old field.

### NO Removing an enum value

**Not allowed.** Old messages can still encode the removed value;
newer consumers must continue to handle it.

### NO Reordering enum values

**Not allowed.** Protobuf's binary encoding uses the value's integer
ordinal, not its name. Reordering silently corrupts data.

### NO Reusing field numbers

**Not allowed.** Use `reserved N;` to block the tag from being
re-introduced by accident.

### NO Changing a `oneof` to/from a non-`oneof` field

**Not allowed.** The wire encoding for `oneof` members differs from
the encoding for a regular field at the same tag.

## Deprecation dance

When a non-`BACKWARD_TRANSITIVE`-compatible change is unavoidable:

1. Bump the schema's package to `v2`:
   `me.tinkle.events.user.v2.UserCreatedEvent`.
2. Register it under a **new subject**:
   `outbox.user.event-value` version `v2` (a separate FileDescriptor
   version under the same subject).
3. Producers dual-write to **both** `v1` and `v2` for one release
   window.
4. Consumers migrate to `v2`.
5. Producers stop dual-writing.
6. The `v1` FileDescriptor is **frozen** (still readable by old
   consumers for replay), but not evolved further.
7. After a defined grace period (typically one quarter), the `v1`
   version of the subject is marked `deleted: true` in the registry.

## CI enforcement

The `.github/workflows/schema-compatibility.yml` workflow runs:

1. `buf lint proto` — catches style / API-CHECK issues via the
   `STANDARD` lint category.
2. `buf breaking --against '.git#branch=main' proto` — catches
   `FIELD_NO_DELETE_UNLESS_NUMBER_RESERVED`,
   `FIELD_SAME_TYPE`, `ENUM_VALUE_NO_DELETE`, etc., via the `FILE`
   breaking category.
3. For each changed `.proto` file, `POST`s the `.proto` text to the
   staging Confluent SR subject
   `POST /subjects/<basename>/versions` with
   `schemaType: PROTOBUF, compatibility: BACKWARD_TRANSITIVE`. A
   `409 Conflict` response fails the PR.

See `scripts/validate.sh` for a local equivalent.
