#!/bin/bash
source "$(dirname "$0")/lib/common.sh"
[[ $# == 0 ]] || fail 'Usage: uninstall-autoupdate.sh'
PLIST="$HOME/Library/LaunchAgents/local.chatgpt-personal.update.plist"
if [[ -e "$PLIST" ]]; then
 launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
 mkdir -p "$HOME/.Trash"
 SLOT=$(mktemp -d "$HOME/.Trash/chatgpt-personal-agent.XXXXXXXX")
 mv "$PLIST" "$SLOT/"
 echo "LaunchAgent disabled and moved to $SLOT"
else echo 'No Personal LaunchAgent installed.'; fi
