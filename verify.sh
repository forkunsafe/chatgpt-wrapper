#!/bin/bash
source "$(dirname "$0")/lib/common.sh"
staged=false
if [[ ${1:-} == --app && $# -ge 2 ]]; then APP=$2; shift 2; fi
if [[ ${1:-} == --staged ]]; then staged=true; shift; fi
[[ $# == 0 ]] || fail 'Usage: verify.sh [--app PATH] [--staged]'
platform
[[ -d "$APP" ]] || fail "$APP missing"
[[ $(get "$APP" CFBundleName) == 'ChatGPT Personal' && $(get "$APP" CFBundleDisplayName) == 'ChatGPT Personal' ]] || fail 'Display name mismatch'
[[ $(get "$APP" CFBundleIdentifier) == "$(get "$SOURCE" CFBundleIdentifier)" ]] || fail 'Bundle identifier changed'
[[ $(get "$APP" CFBundleIconFile) == Personal.icns && -s "$APP/Contents/Resources/Personal.icns" ]] || fail 'Personal icon missing'
[[ $(get "$APP" CFBundleExecutable) == PersonalLauncher && -x "$APP/Contents/MacOS/PersonalLauncher" ]] || fail 'Launcher missing'
real=$(get "$APP" PersonalOriginalExecutable)
[[ "$real" != */* && -x "$APP/Contents/MacOS/$real" ]] || fail 'Preserved executable missing'
[[ -n $(get "$APP" PersonalSourceBundleVersion) && -n $(get "$APP" PersonalSourceShortVersionString) && -n $(get "$APP" PersonalSourceInfoSHA256) ]] || fail 'Source metadata missing'
# A valid seal does not imply AMFI will permit ad-hoc restricted entitlements.
main_entitlements=$(codesign -d --entitlements :- "$APP/Contents/MacOS/$real" 2>/dev/null)
for key in com.apple.application-identifier com.apple.developer.team-identifier com.apple.developer.aps-environment com.apple.developer.usernotifications.communication keychain-access-groups; do
 if printf '%s' "$main_entitlements" | /usr/bin/grep -Fq "<key>$key</key>"; then
  fail "Restricted main entitlement $key prevents ad-hoc launch. Quit Personal and run ./update.sh --force."
 fi
done
codesign --verify --deep --strict --verbose=2 "$APP"
# This privileged helper must keep its developer signature; ad-hoc re-signing
# with its original restricted entitlements passes codesign but fails AMFI.
helper=Contents/Resources/codex-cli/CodexCLI.app
if [[ -d "$SOURCE/$helper" ]]; then
 [[ -d "$APP/$helper" ]] || fail 'Bundled Codex helper missing'
 if [[ $(get "$APP" PersonalSourceBundleVersion) == "$(get "$SOURCE" CFBundleVersion)" ]]; then
  expected=$(codesign -dvv "$SOURCE/$helper" 2>&1 | sed -n '/^CDHash=/p; /^TeamIdentifier=/p')
  actual=$(codesign -dvv "$APP/$helper" 2>&1 | sed -n '/^CDHash=/p; /^TeamIdentifier=/p')
  [[ "$expected" == "$actual" ]] || fail 'Codex helper original signature changed'
 fi
 "$APP/$helper/Contents/MacOS/$(get "$APP/$helper" CFBundleExecutable)" --version
fi
file "$APP/Contents/MacOS/PersonalLauncher"
if [[ $(get "$APP" PersonalSourceBundleVersion) == "$(get "$SOURCE" CFBundleVersion)" ]]; then
 [[ $(get "$APP" PersonalSourceInfoSHA256) == "$(shasum -a 256 "$SOURCE/Contents/Info.plist" | awk '{print $1}')" ]] || fail 'Official metadata differs from recorded source'
fi
codesign --verify --deep --strict "$SOURCE"
echo "Personal source: $(get "$APP" PersonalSourceShortVersionString) ($(get "$APP" PersonalSourceBundleVersion))"
echo "Official source: $(version)"
if ! $staged; then
 [[ -d "$CODEX" && -d "$PROFILE" ]] || fail 'Personal data directories missing'
 listing=$(processes)
 executables=$(ps -axww -o pid=,comm=)
 # Inspect only the preserved main executable, never dump unrelated command lines or environments.
 pids=$(printf '%s\n' "$executables" | awk -v main="$APP/Contents/MacOS/$real" '{pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0==main) print pid}')
 if [[ -z "$pids" ]]; then echo 'Personal main process is not running; runtime environment check pending.'; else
  for pid in $pids; do
   commandline=$(ps -ww -p "$pid" -o command=)
   [[ "$commandline" == *"--user-data-dir=$PROFILE"* ]] || fail "PID $pid: personal argument missing"
   environment=$(ps eww -p "$pid" -o command=)
   [[ "$environment " == *" CODEX_HOME=$CODEX "* ]] || fail "PID $pid: CODEX_HOME not confirmed"
   echo "PID $pid: CODEX_HOME and user-data-dir verified"
  done
 fi
 # open inherits its caller's environment. An agent running in Personal can
 # accidentally launch the official app with Personal's CODEX_HOME too.
 official_pids=$(printf '%s\n' "$executables" | awk -v main="$SOURCE/Contents/MacOS/$(get "$SOURCE" CFBundleExecutable)" '{pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0==main) print pid}')
 for pid in $official_pids; do
  environment=$(ps eww -p "$pid" -o command=)
  [[ "$environment " != *" CODEX_HOME=$CODEX "* ]] || fail "Official PID $pid inherited Personal CODEX_HOME. Quit only the official app, then use: env -u CODEX_HOME open /Applications/ChatGPT.app"
  echo "Official PID $pid: no Personal CODEX_HOME override"
 done
fi
echo 'Verification passed. Official signature valid; recorded official metadata checked when versions match.'
