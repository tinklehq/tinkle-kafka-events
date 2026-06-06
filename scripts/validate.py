#!/usr/bin/env python3
"""Validate every .avsc file in schemas/ is a valid Avro schema.

Uses fastavro. Loads every schema, registers all defined names in a
shared named-types map, and re-parses each schema so that cross-file
references (e.g. `me.tinkle.events.privacy.v1.PrivacyAllowValue`
referenced from the privacy event records) resolve correctly.

Run with: python3 scripts/validate.py
"""
from __future__ import annotations

import json
import pathlib
import sys

import fastavro

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMAS_DIR = REPO_ROOT / "schemas"


def load_all() -> dict[str, dict]:
    """Load every .avsc into a name->schema map keyed by FQN."""
    by_name: dict[str, dict] = {}
    for f in sorted(SCHEMAS_DIR.rglob("*.avsc")):
        with f.open() as fp:
            data = json.load(fp)
        ns = data.get("namespace")
        nm = data["name"]
        fqn = f"{ns}.{nm}" if ns else nm
        if fqn in by_name:
            print(f"WARN: duplicate FQN {fqn} (from {f})", file=sys.stderr)
        by_name[fqn] = data
    return by_name


def main() -> int:
    by_name = load_all()
    if not by_name:
        print("ERROR: no .avsc files found", file=sys.stderr)
        return 1

    # fastavro wants a `named_schemas` dict that maps FQN -> schema
    # (where named types like records, enums, fixed live). We pass it to
    # parse_schema() so cross-file named-type lookups succeed.
    named_schemas: dict[str, dict] = {}

    # First, register every schema's named types so that records and
    # enums can find each other.
    for fqn, schema in by_name.items():
        if schema.get("type") in ("record", "enum", "fixed"):
            named_schemas[fqn] = schema

    # Now parse each schema with the full map available. fastavro will
    # validate the structure and resolve references.
    print(f"Validating {len(by_name)} Avro schema files...")
    bad = 0
    for fqn, schema in by_name.items():
        try:
            fastavro.parse_schema(schema, named_schemas=named_schemas)
            print(f"  OK {fqn}")
        except Exception as e:  # noqa: BLE001
            print(f"  FAIL {fqn}: {e}")
            bad += 1

    if bad:
        print(f"\n{bad} schema(s) failed validation.", file=sys.stderr)
        return 1
    print(f"\nAll {len(by_name)} schemas are valid Avro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
