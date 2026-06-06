#!/usr/bin/env bash
#
# validate.sh — local Avro schema validator.
#
# Verifies that every `.avsc` file under `schemas/` is a valid Avro
# schema, with cross-file named-type references (e.g. an enum defined
# in `schemas/common/enums.avsc` and referenced from a privacy event
# schema) resolved correctly.
#
# This script delegates the actual parsing to a tiny Python helper
# (`scripts/validate.py`) because the Java `avro-tools` jar does not
# easily resolve cross-file Avro named types when invoked one file at
# a time. fastavro is the de-facto reference implementation for Avro
# 1.11.x and is available in CI via `pip install fastavro`.
#
# Usage:
#   ./scripts/validate.sh
#
# Exit code:
#   0  - all schemas valid
#   1  - one or more schemas invalid
#   2  - missing dependency (Python or fastavro)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PY="${PYTHON:-python3}"

# --- 1. Ensure Python is available --------------------------------------------
if ! command -v "${PY}" >/dev/null 2>&1; then
  echo "ERROR: ${PY} not found in PATH. Install Python 3.8+." >&2
  exit 2
fi

# --- 2. Ensure fastavro is available -------------------------------------------
if ! "${PY}" -c 'import fastavro' >/dev/null 2>&1; then
  echo "fastavro not found; attempting to install..."
  if ! "${PY}" -m pip install --user fastavro >/dev/null 2>&1; then
    echo "ERROR: failed to install fastavro. Run: ${PY} -m pip install fastavro" >&2
    exit 2
  fi
fi

# --- 3. Run the validator ------------------------------------------------------
echo "Running ${PY} ${SCRIPT_DIR}/validate.py"
exec "${PY}" "${SCRIPT_DIR}/validate.py"
