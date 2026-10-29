#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
[[ $# -le 1 ]] || { echo 'Usage: update.sh [--force]' >&2; exit 1; }
exec "$ROOT/lib/build.sh" update "${1:-}"
