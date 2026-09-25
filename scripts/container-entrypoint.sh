#!/bin/sh
set -eu

snapshot=/credential-snapshot/opencode.db

if [ ! -f "$snapshot" ]; then
  echo "error: expected a read-only OpenCode DB snapshot at $snapshot" >&2
  echo "mount a snapshot with: -v /path/to/snapshot.db:$snapshot:ro" >&2
  exit 64
fi

# Ask this exact OpenCode build where its DB belongs instead of hard-coding a
# release-specific path. The source remains read-only; OpenCode receives a
# private writable copy inside the disposable container.
db_path="$(opencode debug paths db)"
mkdir -p "$(dirname "$db_path")"
cp "$snapshot" "$db_path"
chmod 0600 "$db_path"

# Every container starts from the same harmless repository. This lets tests use
# writes, edits, git operations, and destructive-looking shell commands without
# touching the host checkout.
cd /
rm -rf /workspace/fixture
mkdir -p /workspace/fixture /workspace/audit
cp -R /opt/fixture-seed/. /workspace/fixture/
cp /workspace/fixture/.env.example /workspace/fixture/.env

git -C /workspace/fixture init -q
git -C /workspace/fixture config user.name "Sandbox User"
git -C /workspace/fixture config user.email "sandbox@example.invalid"
git -C /workspace/fixture add .
git -C /workspace/fixture commit -qm "Initial harmless sandbox fixture"

audit_path="${OPENCODE_PERMISSION_AUDIT:-/workspace/audit/permission-evaluator.jsonl}"
mkdir -p "$(dirname "$audit_path")"
touch "$audit_path"

echo "Guardians of the Diff sandbox" >&2
echo "  fixture: /workspace/fixture (disposable)" >&2
echo "  audit:   $audit_path" >&2
echo "  model:   ${OPENCODE_EVALUATOR_MODEL:-openai/gpt-5.5-fast}" >&2

cd /workspace/fixture

case "${1:-}" in
  run|mini)
    command="$1"
    shift
    exec opencode "$command" --standalone "$@"
    ;;
  *)
    exec opencode --standalone "$@"
    ;;
esac
