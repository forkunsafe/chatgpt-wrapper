#!/bin/bash
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/progress.sh"
source "$(dirname "$0")/retention.sh"
platform
[[ $# == 1 ]] || fail "Usage: install-bundle.sh staged-app"
NEW=$1
LOCK=
if [[ -d "$APP" ]]; then
 previous_version="$(get "$APP" PersonalSourceShortVersionString || echo unknown) ($(get "$APP" PersonalSourceBundleVersion || echo unknown))"
else previous_version='not installed'; fi
[[ -d "$NEW" ]] || fail "Staged app missing"
progress_start 5 "$(dirname "$NEW")/install.log"
finish_install() {
 local status=$?
 progress_cleanup
 [[ -z ${LOCK:-} ]] || rmdir "$LOCK" || true
 if [[ $status != 0 ]]; then
  echo "Installation failed; diagnostic files retained: $(dirname "$NEW")" >&2
 elif [[ ${PERSONAL_BUILD_DRIVER:-} != 1 ]]; then
  archive_build_logs "$(dirname "$NEW")" || echo 'Warning: could not archive installation log.' >&2
 fi
}
trap finish_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "Installation log: $PROGRESS_LOG"
phase "Verify staged app before installation"
run_logged "$ROOT/verify.sh" --app "$NEW" --staged
[[ $(get "$NEW" PersonalSourceInfoSHA256) == "$(shasum -a 256 "$SOURCE/Contents/Info.plist" | awk '{print $1}')" ]] || fail "Official source changed; rebuild"
not_running
mkdir -p "$HOME/Applications"
# Serialize installers and hold the lock through final process check and replacement.
lock_path="$HOME/Applications/.chatgpt-personal-install.lock"
mkdir "$lock_path" 2>/dev/null || fail "Installer lock exists: $lock_path (inspect before manually removing)"
LOCK=$lock_path
not_running
[[ -d "$CODEX" || ! -e "$CODEX" ]] || fail "$CODEX is not a directory"
[[ -d "$PROFILE" || ! -e "$PROFILE" ]] || fail "$PROFILE is not a directory"
mkdir -p "$CODEX" "$PROFILE"
# Stage on the destination filesystem, then two renames; retain old app for rollback.
SLOT=$(mktemp -d "$HOME/Applications/.chatgpt-personal.XXXXXXXX")
phase "Copy verified app to the installation filesystem"
run_logged ditto "$NEW" "$SLOT/ChatGPT Personal.app"
phase "Verify the installation copy"
run_logged codesign --verify --deep --strict "$SLOT/ChatGPT Personal.app"
not_running
phase "Replace Personal and register it with Finder/Dock"
had_previous=false
if [[ -e "$APP" || -L "$APP" ]]; then had_previous=true; mv "$APP" "$SLOT/Previous ChatGPT Personal.app"; fi
if ! mv "$SLOT/ChatGPT Personal.app" "$APP"; then
 [[ ! -e "$SLOT/Previous ChatGPT Personal.app" ]] || mv "$SLOT/Previous ChatGPT Personal.app" "$APP"
 fail 'Install failed; previous app restored'
fi
touch "$APP"
"$LSREGISTER" -f "$APP" || echo 'Warning: LaunchServices registration failed; use open with the full app path.'
phase "Verify installed app and retain one rollback copy"
if ! run_logged "$ROOT/verify.sh" --app "$APP" --staged; then
 mv "$APP" "$SLOT/Rejected ChatGPT Personal.app"
 if $had_previous; then mv "$SLOT/Previous ChatGPT Personal.app" "$APP"; fi
 fail "Final verification failed; previous installation restored (if present). Rejected app retained: $SLOT"
fi
if $had_previous; then
 if ! prune_rollback_slots "$HOME/Applications" "$SLOT"; then
  echo 'Warning: installation succeeded, but some older backups could not be removed.' >&2
 fi
else rmdir "$SLOT"; fi
echo
echo "Installation successful."
echo "Personal source: $previous_version -> $(get "$APP" PersonalSourceShortVersionString) ($(get "$APP" PersonalSourceBundleVersion))"
echo "Installed: $APP"
if $had_previous; then echo "Rollback copy: $SLOT/Previous ChatGPT Personal.app"; else echo "New installation; no previous app to back up."; fi
echo "Signature and launcher checks passed. Existing personal data preserved."
echo "CODEX_HOME=$CODEX"
echo "user-data-dir=$PROFILE"
