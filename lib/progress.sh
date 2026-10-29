#!/bin/bash
# Plain lines work equally well in a terminal and LaunchAgent logs.
progress_start() {
 PROGRESS_STARTED=$SECONDS
 PROGRESS_PHASE=0
 PROGRESS_TOTAL=$1
 PROGRESS_LOG=$2
 PROGRESS_ACTIVE_PID=
 PROGRESS_LABEL=setup
}
phase() {
 PROGRESS_PHASE=$((PROGRESS_PHASE + 1))
 PROGRESS_LABEL=$1
 printf '\n[%s/%s] %s\n' "$PROGRESS_PHASE" "$PROGRESS_TOTAL" "$PROGRESS_LABEL"
}
run_logged() {
 local started=$SECONDS last=$SECONDS status
 "$@" >> "$PROGRESS_LOG" 2>&1 &
 PROGRESS_ACTIVE_PID=$!
 while kill -0 "$PROGRESS_ACTIVE_PID" 2>/dev/null; do
  sleep 1
  if (( SECONDS - last >= 10 )); then
   printf '  Still working: %s (%ss)\n' "$PROGRESS_LABEL" "$((SECONDS - started))"
   last=$SECONDS
  fi
 done
 if wait "$PROGRESS_ACTIVE_PID"; then status=0; else status=$?; fi
 PROGRESS_ACTIVE_PID=
 if [[ $status != 0 ]]; then
  printf '  FAILED: %s (exit %s). Log: %s\n' "$PROGRESS_LABEL" "$status" "$PROGRESS_LOG" >&2
  tail -n 20 "$PROGRESS_LOG" >&2
  return "$status"
 fi
 printf '  Done (%ss)\n' "$((SECONDS - started))"
}
progress_cleanup() {
 # Only build/verification commands started by run_logged; never an app process.
 if [[ -n ${PROGRESS_ACTIVE_PID:-} ]]; then
  kill "$PROGRESS_ACTIVE_PID" 2>/dev/null || true
  wait "$PROGRESS_ACTIVE_PID" 2>/dev/null || true
 fi
}
