#!/bin/bash
source "$(dirname "$0")/lib/common.sh"
[[ $# == 0 ]] || fail 'Usage: uninstall.sh (data purge intentionally unsupported)'
not_running
"$ROOT/uninstall-autoupdate.sh"
if [[ -e "$APP" ]]; then
 mkdir -p "$HOME/.Trash"
 SLOT=$(mktemp -d "$HOME/.Trash/chatgpt-personal-app.XXXXXXXX")
 mv "$APP" "$SLOT/"
 echo "App moved to $SLOT"
fi
echo "Preserved Codex data: $CODEX"
echo "Preserved ChatGPT profile: $PROFILE"
