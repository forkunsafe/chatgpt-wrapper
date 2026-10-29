#!/bin/bash
source "$(dirname "$0")/lib/common.sh"
platform
[[ $# == 0 ]] || fail 'Usage: install-autoupdate.sh'
if [[ -n ${PERSONAL_UPDATE_COMMAND:-} ]]; then
 [[ "$PERSONAL_UPDATE_COMMAND" == /* && -x "$PERSONAL_UPDATE_COMMAND" ]] || fail 'Updater command must be an absolute executable path'
fi
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/ChatGPT-Personal"
PLIST="$HOME/Library/LaunchAgents/local.chatgpt-personal.update.plist"
[[ ! -e "$PLIST" ]] || fail 'LaunchAgent already exists; uninstall it first to replace it'
cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>local.chatgpt-personal.update</string><key>ProgramArguments</key><array><string>/bin/bash</string><string>PLACEHOLDER</string></array><key>StartInterval</key><integer>3600</integer><key>RunAtLoad</key><true/><key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict></dict></plist>
PLIST
"$PB" -c "Set :ProgramArguments:1 $ROOT/update.sh" "$PLIST"
if [[ -n ${PERSONAL_UPDATE_COMMAND:-} ]]; then
 "$PB" -c "Set :ProgramArguments:1 $PERSONAL_UPDATE_COMMAND" "$PLIST"
 "$PB" -c 'Add :ProgramArguments:2 string update' "$PLIST"
fi
setlog="$HOME/Library/Logs/ChatGPT-Personal/update.log"
"$PB" -c "Add :StandardOutPath string $setlog" "$PLIST"
"$PB" -c "Add :StandardErrorPath string $setlog" "$PLIST"
plutil -lint "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Hourly update check installed: $PLIST."
echo "Updater: ${PERSONAL_UPDATE_COMMAND:-$ROOT/update.sh}. Keep this path available."
