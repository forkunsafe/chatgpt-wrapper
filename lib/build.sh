#!/bin/bash
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/progress.sh"
source "$(dirname "$0")/retention.sh"
platform
mode=${1:-install}; [[ "$mode" != --build-only ]] || mode=build-only
force=${2:-}
[[ -z "$force" || "$force" == --force ]] || fail 'Usage: update.sh [--force]'
echo "Official source: $(version)"
if [[ -d "$APP" ]]; then
 echo "Personal source: $(get "$APP" PersonalSourceShortVersionString || echo unknown) ($(get "$APP" PersonalSourceBundleVersion || echo unknown))"
else echo 'Personal app: not installed'; fi
[[ "$force" != --force ]] || echo 'Forced rebuild requested, even if versions match.'
if [[ "$mode" == update && -d "$APP" && "$force" != --force ]]; then
 if [[ $(get "$APP" PersonalSourceBundleVersion || true) == "$(get "$SOURCE" CFBundleVersion)" && $(get "$APP" PersonalSourceShortVersionString || true) == "$(get "$SOURCE" CFBundleShortVersionString)" && $(get "$APP" PersonalBuildSchema || true) == "$BUILD_SCHEMA" ]]; then
  echo 'Already up to date. Nothing changed. Use --force to rebuild.'; exit 0
 fi
fi
# --build-only stages without installing or accessing profile contents.
if [[ "$mode" != build-only ]]; then not_running; fi
command -v go >/dev/null || fail 'Go required at build time. Install from https://go.dev/dl/ then retry; nothing was installed.'
command -v xcrun >/dev/null || fail 'Apple Command Line Tools required: xcode-select --install'
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-personal.XXXXXXXX")
STAGE=$(cd "$STAGE" && pwd -P)
: > "$STAGE/.chatgpt-personal-build"
BUILD_PARENT=$(dirname "$STAGE")
progress_start 8 "$STAGE/build.log"
finish_build() {
 local status=$?
 progress_cleanup
 finish_build_workspace "$status" "$mode" "$STAGE" "$BUILD_PARENT"
}
trap finish_build EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "Build log: $PROGRESS_LOG"
echo 'The build may take several minutes; the installed app is replaced only after verification.'
NEW="$STAGE/ChatGPT Personal.app"
before="$(source_id)"
phase "Verify the official source signature"
run_logged /usr/bin/codesign --verify --deep --strict "$SOURCE"
phase "Copy the official app into a temporary workspace"
run_logged /usr/bin/ditto "$SOURCE" "$NEW"
original=$(get "$SOURCE" CFBundleExecutable)
[[ "$original" != */* && -n "$original" && "$original" != PersonalLauncher ]] || fail 'Unsupported source executable name'
real="$original.real"
[[ ! -e "$NEW/Contents/MacOS/$real" ]] || fail 'Source already contains preserved executable name'
/usr/bin/codesign -d --entitlements :- "$SOURCE" > "$STAGE/main-entitlements.plist" 2> "$STAGE/main-signature.txt"
# Record entitlement payloads for every signed nested file/bundle, without following symlinks.
mkdir "$STAGE/entitlements"
phase "Inspect nested signatures and capture entitlements"
index=0
scanned=0
scan_started=$SECONDS
scan_last=$SECONDS
while IFS= read -r -d '' entry; do
 scanned=$((scanned+1))
 if (( SECONDS - scan_last >= 10 )); then
  printf '  Inspected %s files/directories; found %s signed objects (%ss)\n' "$scanned" "$index" "$((SECONDS - scan_started))"
  scan_last=$SECONDS
 fi
 if /usr/bin/codesign -d --entitlements :- "$entry" > "$STAGE/entitlements/$index.plist" 2>/dev/null; then
  printf '%s\n' "${entry#"$NEW"/}" > "$STAGE/entitlements/$index.path"
  index=$((index+1))
 fi
done < <(find "$NEW/Contents" \( -type f -o -type d \) -print0)
echo "  Done: $scanned files/directories inspected, $index signed objects recorded."
phase "Build the native Go launcher and patch app metadata"
mv "$NEW/Contents/MacOS/$original" "$NEW/Contents/MacOS/$real"
run_logged env CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 GOCACHE="$STAGE/go-cache" go -C "$ROOT/launcher" build -trimpath -ldflags "-s -w -X main.realName=$real" -o "$NEW/Contents/MacOS/PersonalLauncher" .
setkey "$NEW" CFBundleExecutable PersonalLauncher
setkey "$NEW" CFBundleName 'ChatGPT Personal'
setkey "$NEW" CFBundleDisplayName 'ChatGPT Personal'
setkey "$NEW" PersonalSourceBundleVersion "$(get "$SOURCE" CFBundleVersion)"
setkey "$NEW" PersonalSourceShortVersionString "$(get "$SOURCE" CFBundleShortVersionString)"
setkey "$NEW" PersonalOriginalExecutable "$real"
setkey "$NEW" PersonalBuildSchema "$BUILD_SCHEMA"
setkey "$NEW" PersonalSourceInfoSHA256 "$(shasum -a 256 "$SOURCE/Contents/Info.plist" | awk '{print $1}')"
# Prevent localized display names and the official icon name from overriding ours.
"$PB" -c 'Delete :CFBundleIconName' "$NEW/Contents/Info.plist" 2>/dev/null || true
"$PB" -c 'Delete :LSHasLocalizedDisplayName' "$NEW/Contents/Info.plist" 2>/dev/null || true
while IFS= read -r -d '' localized; do
 plutil -convert xml1 "$localized"
 plutil -replace CFBundleDisplayName -string 'ChatGPT Personal' "$localized"
 plutil -replace CFBundleName -string 'ChatGPT Personal' "$localized"
done < <(find "$NEW/Contents/Resources" -maxdepth 2 -name InfoPlist.strings -print0)
phase "Generate and install the Personal icon"
icon=$(get "$SOURCE" CFBundleIconFile)
[[ "$icon" != */* && -n "$icon" ]] || fail 'Unsupported source icon resource'
[[ "$icon" == *.icns ]] || icon="$icon.icns"
if [[ -f "$ROOT/assets/Personal.icns" ]]; then
 ditto "$ROOT/assets/Personal.icns" "$NEW/Contents/Resources/Personal.icns"
else
 run_logged xcrun swiftc -module-cache-path "$STAGE/swift-cache" "$ROOT/assets/icon.swift" -o "$STAGE/icon-generator"
 "$STAGE/icon-generator" "$SOURCE/Contents/Resources/$icon" "$STAGE/Personal.iconset"
 run_logged iconutil -c icns "$STAGE/Personal.iconset" -o "$NEW/Contents/Resources/Personal.icns"
fi
setkey "$NEW" CFBundleIconFile Personal.icns
# ChatGPT can select its Dock icon dynamically; badge that original asset too.
base=$(get "$SOURCE" CodexAppIconBaseName || true)
if [[ -n "$base" && "$base" != */* ]]; then
 if [[ -f "$SOURCE/Contents/Resources/$base.icns" && ! -f "$ROOT/assets/Personal.icns" ]]; then
  "$STAGE/icon-generator" "$SOURCE/Contents/Resources/$base.icns" "$STAGE/Dock.iconset"
  run_logged iconutil -c icns "$STAGE/Dock.iconset" -o "$NEW/Contents/Resources/$base.icns"
  ditto "$STAGE/Dock.iconset/icon_512x512@2x.png" "$NEW/Contents/Resources/$base.png"
 else
  ditto "$NEW/Contents/Resources/Personal.icns" "$NEW/Contents/Resources/$base.icns"
  sips -s format png "$NEW/Contents/Resources/Personal.icns" --out "$NEW/Contents/Resources/$base.png" >/dev/null
 fi
fi
phase "Sign the launcher and main executable; keep nested official signatures"
# The Go trampoline needs no entitlements. Apple's restricted developer/keychain/push
# entitlements cannot be validated for an ad-hoc main executable (AMFI rejects it).
ditto "$STAGE/main-entitlements.plist" "$STAGE/real-entitlements.plist"
for key in com.apple.application-identifier com.apple.developer.team-identifier com.apple.developer.aps-environment com.apple.developer.associated-domains com.apple.developer.usernotifications.communication keychain-access-groups; do
 "$PB" -c "Delete :$key" "$STAGE/real-entitlements.plist" 2>/dev/null || true
done
setkey "$NEW" PersonalEntitlementPolicy 'ad-hoc-compatible-main; original nested signatures preserved'
# Preserve all nested official signatures. The ad-hoc main process must be able
# to load those developer-signed frameworks despite having no developer Team ID.
"$PB" -c 'Delete :com.apple.security.cs.disable-library-validation' "$STAGE/real-entitlements.plist" 2>/dev/null || true
"$PB" -c 'Add :com.apple.security.cs.disable-library-validation bool true' "$STAGE/real-entitlements.plist"
run_logged codesign --force --sign - --options runtime --entitlements "$STAGE/real-entitlements.plist" "$NEW/Contents/MacOS/$real"
run_logged codesign --force --sign - "$NEW"
phase "Verify the final signature and compare entitlements"
run_logged codesign --verify --deep --strict --verbose=2 "$NEW"
for pathfile in "$STAGE"/entitlements/*.path; do
 entry=$(cat "$pathfile")
 [[ "$entry" != "Contents/MacOS/$original" ]] || entry="Contents/MacOS/$real"
 codesign -d --entitlements :- "$NEW/$entry" > "$STAGE/after.plist" 2>/dev/null
 payload="${pathfile%.path}.plist"
 [[ "$entry" != "Contents/MacOS/$real" ]] || payload="$STAGE/real-entitlements.plist"
 if [[ -s "$payload" || -s "$STAGE/after.plist" ]]; then
  plutil -convert xml1 -o "$STAGE/expected-normalized.plist" "$payload"
  plutil -convert xml1 -o "$STAGE/actual-normalized.plist" "$STAGE/after.plist"
  cmp "$STAGE/expected-normalized.plist" "$STAGE/actual-normalized.plist" || fail "Entitlements changed: $entry"
 fi
done
codesign -d --entitlements :- "$NEW" > "$STAGE/after-main.plist" 2>/dev/null
[[ ! -s "$STAGE/after-main.plist" ]] || fail 'Go launcher unexpectedly has entitlements'
[[ "$before" == "$(source_id)" ]] || fail 'Official source changed during build; retry'
echo "  $index signed-object entitlement payloads verified; official source unchanged."
phase "Run final app checks"
run_logged "$ROOT/verify.sh" --app "$NEW" --staged
if [[ "$mode" == build-only ]]; then echo "Build successful in $((SECONDS - PROGRESS_STARTED))s. Verified staged bundle: $NEW"; echo "Signature, metadata, icon and launcher checks passed."; echo "Installed app and personal data were not changed."; exit 0; fi
PERSONAL_BUILD_DRIVER=1 "$ROOT/lib/install-bundle.sh" "$NEW"
echo "Completed in $((SECONDS - PROGRESS_STARTED))s."
