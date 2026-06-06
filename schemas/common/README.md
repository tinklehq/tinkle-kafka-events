# schemas/common/

Shared types referenced from every other schema in this repo.

| File | Purpose |
| ---- | ------- |
| `envelope.avsc` | Standard wrapper for every topic. The Envelope's `payload` field is `bytes` containing the Avro-encoded concrete event. See `../../docs/envelope.md`. |
| `enums.avsc` | `PrivacyAllowValue` enum (used by privacy events). |
| `enums_privacy_action.avsc` | `PrivacyRuleAction` enum (used by privacy rule events). |

These enums live in `common/` for discovery but are namespaced under
the privacy service (`io.tinklehq.events.privacy.v1.*`) intentionally:
they're logically owned by the privacy service's contract, not by a
shared utility package. The placement in `common/` is purely
organisational so the privacy schemas can reference them without a
circular import.
