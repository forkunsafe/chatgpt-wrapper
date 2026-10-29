#!/bin/bash
# Generate a real plist in a fixture HOME; never contact the real launchd.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-agent-test.XXXXXXXX")
mkdir -p "$WORK/bin" "$WORK/home" "$WORK/stable tools"
printf '#!/bin/bash\nexit 0\n' > "$WORK/bin/launchctl"
cp "$WORK/bin/launchctl" "$WORK/stable tools/chatgpt-personal"
chmod +x "$WORK/bin/launchctl" "$WORK/stable tools/chatgpt-personal"
env HOME="$WORK/home" PATH="$WORK/bin:$PATH" PERSONAL_UPDATE_COMMAND="$WORK/stable tools/chatgpt-personal" "$ROOT/install-autoupdate.sh"
plist="$WORK/home/Library/LaunchAgents/local.chatgpt-personal.update.plist"
PB=/usr/libexec/PlistBuddy
[[ $("$PB" -c 'Print :ProgramArguments:0' "$plist") == /bin/bash ]]
[[ $("$PB" -c 'Print :ProgramArguments:1' "$plist") == "$WORK/stable tools/chatgpt-personal" ]]
[[ $("$PB" -c 'Print :ProgramArguments:2' "$plist") == update ]]
env HOME="$WORK/home" PATH="$WORK/bin:$PATH" "$ROOT/uninstall-autoupdate.sh"
[[ ! -e "$plist" ]]
env -u PERSONAL_UPDATE_COMMAND HOME="$WORK/home" PATH="$WORK/bin:$PATH" "$ROOT/install-autoupdate.sh"
[[ $("$PB" -c 'Print :ProgramArguments:1' "$plist") == "$ROOT/update.sh" ]]
if "$PB" -c 'Print :ProgramArguments:2' "$plist" >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$WORK/home/.codex-personal" ]]
echo "LaunchAgent stable command and source-install checks passed ($WORK)"
