#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
[[ $# == 0 || ( $# == 1 && "$1" == --build-only ) ]] || { echo 'Usage: install.sh [--build-only]' >&2; exit 1; }
exec "$ROOT/lib/build.sh" "${1:-install}"
