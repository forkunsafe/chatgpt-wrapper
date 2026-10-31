#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE=/Applications/ChatGPT.app
APP="$HOME/Applications/ChatGPT Personal.app"
PROFILE="$HOME/Library/Application Support/ChatGPT-Personal"
CODEX="$HOME/.codex-personal"
BUILD_SCHEMA=4
PB=/usr/libexec/PlistBuddy
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
fail() { echo "Error: $*" >&2; exit 1; }
get() { "$PB" -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }
setkey() { "$PB" -c "Delete :$2" "$1/Contents/Info.plist" 2>/dev/null || true; "$PB" -c "Add :$2 string $3" "$1/Contents/Info.plist"; }
platform() { [[ $(uname -s) == Darwin ]] || fail 'macOS required'; [[ $(uname -m) == arm64 ]] || fail 'This project targets Apple Silicon (arm64)'; [[ -d "$SOURCE" ]] || fail "$SOURCE missing"; }
processes() { /bin/ps -axww -o pid=,command= || fail 'Cannot inspect processes; refusing unsafe update'; }
personal_pids() {
 local listing
 listing="$(processes)" || return 1
 printf '%s\n' "$listing" | awk -v arg="--user-data-dir=$PROFILE" -v splitarg="--user-data-dir $PROFILE" -v bundle="$APP/Contents/" 'index($0,arg) || index($0,splitarg) || index($0,bundle) { print $1 }'
}
not_running() { local pids; pids="$(personal_pids)" || fail 'Process inspection failed'; [[ -z "$pids" ]] || fail "Personal processes are running (PIDs: $pids). Quit ChatGPT Personal first; no processes were killed."; }
source_id() { /usr/bin/shasum -a 256 "$SOURCE/Contents/Info.plist"; /usr/bin/codesign -dvv "$SOURCE" 2>&1 | sed -n '/^CDHash=/p'; }
version() { printf '%s (%s) [%s], executable %s\n' "$(get "$SOURCE" CFBundleShortVersionString)" "$(get "$SOURCE" CFBundleVersion)" "$(get "$SOURCE" CFBundleIdentifier)" "$(get "$SOURCE" CFBundleExecutable)"; }
