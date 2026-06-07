#!/usr/bin/env bash
#
# validate.sh — local Protobuf schema validator.
#
# Verifies that every `.proto` file under `proto/` is well-formed,
# the Buf `STANDARD` lint category is satisfied, and no wire-incompatible
# change has been made against `main`.
#
# This script delegates the actual parsing to the Buf CLI because
# Buf's `STANDARD` lint category enforces the Buf style guide
# (enforced by the `MINIMAL` lint subcategory) — including the
# `proto/<dotted>/<v1>/` directory layout that the Buf style guide
# recommends.
#
# Usage:
#   ./scripts/validate.sh
#
# Exit code:
#   0  - all schemas valid
#   1  - one or more schemas invalid
#   2  - missing dependency (Buf)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- 1. Ensure buf is available -----------------------------------------------
if ! command -v buf >/dev/null 2>&1; then
  echo "ERROR: buf not found in PATH." >&2
  echo "  Install: brew install bufbuild/buf/buf" >&2
  echo "  Or:       https://buf.build/docs/installation" >&2
  exit 2
fi

# --- 2. Detect whether proto/ has any .proto files --------------------------
if [ -z "$(find "${REPO_ROOT}/proto" -name '*.proto' -type f 2>/dev/null)" ]; then
  echo "No .proto files in proto/ yet — nothing to validate."
  exit 0
fi

# --- 3. Run buf lint ----------------------------------------------------------
echo "==> buf lint"
buf lint "${REPO_ROOT}/proto"

# --- 4. Run buf format check --------------------------------------------------
echo "==> buf format -d (no-op on well-formatted files)"
buf format -d "${REPO_ROOT}/proto"

# --- 5. Run buf breaking against main ----------------------------------------
if git show-ref --verify --quiet "refs/heads/${BASE_BRANCH:-main}" 2>/dev/null \
   || git rev-parse --verify "${BASE_BRANCH:-main}" >/dev/null 2>&1; then
  if [ -n "$(git -C "${REPO_ROOT}" ls-tree -r --name-only "${BASE_BRANCH:-main}" -- proto 2>/dev/null | grep '\.proto$')" ]; then
    echo "==> buf breaking --against '.git#branch=${BASE_BRANCH:-main}'"
    buf breaking --against ".git#branch=${BASE_BRANCH:-main}" "${REPO_ROOT}/proto"
  else
    echo "==> (skipping buf breaking — no .proto files on '${BASE_BRANCH:-main}' yet)"
  fi
else
  echo "==> (skipping buf breaking — no '${BASE_BRANCH:-main}' ref available)"
fi

echo
echo "All Protobuf schemas are valid."
