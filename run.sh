#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="${OPENCODE_SANDBOX_IMAGE:-guardians-of-the-diff:2.0.15}"
snapshot="${1:-${OPENCODE_DB_SNAPSHOT:-}}"

if [[ -z "$snapshot" ]]; then
  echo "usage: $0 /path/to/opencode-db-snapshot" >&2
  echo "or set OPENCODE_DB_SNAPSHOT" >&2
  exit 64
fi

if [[ ! -f "$snapshot" ]]; then
  echo "error: DB snapshot is not a regular file: $snapshot" >&2
  exit 66
fi

mkdir -p "$root/audit"

docker run --rm -it --init \
  --name guardians-of-the-diff \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 256 \
  --env TERM="${TERM:-xterm-256color}" \
  --env COLORTERM="${COLORTERM:-truecolor}" \
  --env 'OPENCODE_CLI_CONFIG_CONTENT={"session":{"permissions":"prompt"}}' \
  --env OPENCODE_EVALUATOR_MODEL="${OPENCODE_EVALUATOR_MODEL:-openai/gpt-5.5-fast}" \
  --env OPENCODE_EVALUATOR_TIMEOUT_MS="${OPENCODE_EVALUATOR_TIMEOUT_MS:-20000}" \
  --mount "type=bind,src=$(cd "$(dirname "$snapshot")" && pwd)/$(basename "$snapshot"),dst=/credential-snapshot/opencode.db,readonly" \
  --mount "type=bind,src=$root/audit,dst=/workspace/audit" \
  "$image"
