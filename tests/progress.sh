#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/progress.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-progress-test.XXXXXXXX")
progress_start 3 "$WORK/commands.log"
phase 'Successful command'
run_logged /bin/echo 'detailed output stays in the log' > "$WORK/success.out"
[[ $(cat "$WORK/success.out") == *Done* ]]
[[ $(cat "$WORK/commands.log") == *'detailed output stays in the log'* ]]
[[ $(cat "$WORK/success.out") != *'detailed output stays in the log'* ]]
phase 'Failing command'
if run_logged /bin/bash -c 'echo deliberate-failure >&2; exit 7' > "$WORK/failure.out" 2>&1; then
 echo 'Failure status was lost' >&2; exit 1
else status=$?; fi
[[ $status == 7 ]]
[[ $(cat "$WORK/failure.out") == *'FAILED: Failing command (exit 7)'* ]]
[[ $(cat "$WORK/failure.out") == *deliberate-failure* ]]
[[ -z "$PROGRESS_ACTIVE_PID" ]]
phase 'Long command'
run_logged /bin/sleep 11 > "$WORK/slow.out"
[[ $(cat "$WORK/slow.out") == *'Still working: Long command'* ]]
[[ $(cat "$WORK/slow.out") == *Done* ]]
echo "Progress success/failure/heartbeat tests passed ($WORK)"
