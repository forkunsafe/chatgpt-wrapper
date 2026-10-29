#!/bin/bash
# Same-version apps with an older signing policy must not be skipped.
source "$(dirname "$0")/../lib/common.sh"
platform
WORK=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-policy-test.XXXXXXXX")
fixture="$WORK/home/Applications/ChatGPT Personal.app"
mkdir -p "$fixture/Contents"
ditto "$SOURCE/Contents/Info.plist" "$fixture/Contents/Info.plist"
setkey "$fixture" PersonalSourceBundleVersion "$(get "$SOURCE" CFBundleVersion)"
setkey "$fixture" PersonalSourceShortVersionString "$(get "$SOURCE" CFBundleShortVersionString)"
setkey "$fixture" PersonalBuildSchema "$BUILD_SCHEMA"
# Exclude Go so the old-policy branch stops before making a bundle or profiles.
env HOME="$WORK/home" PATH=/usr/bin:/bin /bin/bash "$ROOT/update.sh" > "$WORK/current.out" 2>&1
[[ $(cat "$WORK/current.out") == *'Already up to date.'* ]] || fail 'Matching policy was not skipped'
setkey "$fixture" PersonalBuildSchema "$((BUILD_SCHEMA-1))"
if env HOME="$WORK/home" PATH=/usr/bin:/bin /bin/bash "$ROOT/update.sh" > "$WORK/old.out" 2>&1; then
 fail 'Old signing policy was incorrectly skipped'
fi
[[ $(cat "$WORK/old.out") == *'Go required at build time'* ]] || fail 'Old-policy update did not reach rebuild prerequisites'
[[ ! -e "$WORK/home/.codex-personal" ]] || fail 'Fixture profile unexpectedly created'
echo "Update-policy regression passed ($WORK)"
