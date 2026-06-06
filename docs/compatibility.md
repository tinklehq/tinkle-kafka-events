# Compatibility policy

> The rules that every schema in this repo MUST follow.

## Modes

Confluent Schema Registry (and compatible registries) supports four
compatibility modes:

| Mode       | Direction                                  | Use case                                |
| ---------- | ------------------------------------------ | --------------------------------------- |
| `BACKWARD` | New consumer can read old data             | Upgrade **consumers** before producers  |
| `FORWARD`  | Old consumer can read new data             | Upgrade **producers** before consumers  |
| `FULL`     | Both directions                            | Independent upgrade order               |
| `NONE`     | No check                                   | Never in production                     |

This repository uses **`BACKWARD`** as the default. Backward is the
safest default because:

* It is the Confluent Schema Registry default.
* It allows consumers to lag producers by N versions without breakage,
  which is the realistic deployment order for Tinkle.
* The cost of "add a field with a default" is negligible, and the cost
  of "remove a field" is rare and intentional.

`FORWARD` is used for hot-path topics that demand symmetric flexibility
(not currently the case for any topic in this repo). `FULL` is reserved
for topics shared with external clients (none yet).

## Rules

### YES Adding a new field

Always allowed **iff** the new field has a `default`.

```jsonc
{ "name": "country_code", "type": ["null", "string"], "default": null }
```

### YES Removing a field

Allowed **iff** the field being removed has a `default` in the previous
version. (Old consumers can ignore the missing field via the default.)

### YES Adding a new symbol to an enum

Allowed. Existing data still decodes against the new enum (the symbol
just becomes "unknown" to a consumer that hasn't been updated).

### YES Type promotion

Allowed only for these safe promotions:

| From     | To         |
| -------- | ---------- |
| `int`    | `long`     |
| `float`  | `double`   |
| `string` | `bytes` (sometimes — check with consumers) |

### NO Renaming a field or enum symbol

**Not allowed.** Renames are a breaking change. The field's data is
present in old messages but the new name doesn't see it. To rename,
introduce a new field with the new name, dual-write for one version,
then deprecate the old field.

### NO Changing a field's type

**Not allowed** except for the safe promotions above. A `long` -> `int`
change loses precision for any value > 2^31.

### NO Removing an enum symbol

**Not allowed.** Old messages can still encode the removed symbol;
newer consumers must continue to handle it (or fail loudly).

### NO Reordering enum symbols

**Not allowed.** Avro's binary encoding uses the symbol's **position**
in the enum, not its name. Reordering silently corrupts data.

## The deprecation dance

When a non-backward-compatible change is unavoidable:

1. Bump the schema's namespace to `v2`:
   `me.tinkle.events.user.v2.UserCreatedEvent`.
2. Register it under a **new subject**:
   `outbox.user.event-value` version 2.
3. Producers dual-write to **both** `v1` and `v2` for one release
   window.
4. Consumers migrate to `v2`.
5. Producers stop dual-writing.
6. The `v1` subject is **frozen** (still readable by old consumers for
   replay), but not evolved further.
7. After a defined grace period (typically one quarter), the `v1`
   subject is marked `deleted: true` in the registry.

## CI enforcement

The `.github/workflows/compatibility.yml` workflow
registers every changed schema against a staging Schema Registry using
`compatibility: BACKWARD` and fails the PR if the registration
returns 409 Conflict.

See `scripts/validate.sh` for a local equivalent.
