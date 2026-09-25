#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="${OPENCODE_SANDBOX_IMAGE:-guardians-of-the-diff:2.0.15}"

docker build --pull=false --tag "$image" "$root"
