#!/bin/bash
source "$(dirname "$0")/../lib/common.sh"
source "$ROOT/lib/retention.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-retention-test.XXXXXXXX")
WORK=$(cd "$WORK" && pwd -P)
make_app() {
 mkdir -p "$1/Contents"
 echo '<?xml version="1.0"?><plist version="1.0"><dict/></plist>' > "$1/Contents/Info.plist"
 setkey "$1" CFBundleDisplayName 'ChatGPT Personal'
 setkey "$1" PersonalSourceShortVersionString "$2"
 setkey "$1" PersonalSourceBundleVersion "$2"
}
# Deletion guards: unmarked directories, symlinks and unrelated contents survive.
mkdir -p "$WORK/temp" "$WORK/data"
echo production > "$WORK/data/sentinel"
marked="$WORK/temp/chatgpt-personal.12345678"
mkdir "$marked"; touch "$marked/.chatgpt-personal-build"
remove_build_workspace "$marked" "$WORK/temp"
[[ ! -e "$marked" ]]
unmarked="$WORK/temp/chatgpt-personal.abcdefgh"
mkdir "$unmarked"
if remove_build_workspace "$unmarked" "$WORK/temp"; then fail 'Unmarked directory removed'; fi
ln -s "$WORK/data" "$WORK/temp/chatgpt-personal.symlink1"
if remove_build_workspace "$WORK/temp/chatgpt-personal.symlink1" "$WORK/temp"; then fail 'Symlink accepted'; fi
[[ $(cat "$WORK/data/sentinel") == production ]]

# Exercise the real exit policy: normal success cleans, failure/build-only keep.
for name in success1 failure1 buildon1; do
 mkdir "$WORK/temp/chatgpt-personal.$name"
 touch "$WORK/temp/chatgpt-personal.$name/.chatgpt-personal-build"
 echo diagnostic > "$WORK/temp/chatgpt-personal.$name/build.log"
done
HOME="$WORK/log-home" finish_build_workspace 0 install "$WORK/temp/chatgpt-personal.success1" "$WORK/temp" > "$WORK/archive.out"
[[ ! -e "$WORK/temp/chatgpt-personal.success1" ]]
[[ -n $(find "$WORK/log-home" -name build.log -print) ]]
finish_build_workspace 1 install "$WORK/temp/chatgpt-personal.failure1" "$WORK/temp" > "$WORK/failed.out" 2>&1
finish_build_workspace 0 build-only "$WORK/temp/chatgpt-personal.buildon1" "$WORK/temp" > "$WORK/build-only.out"
[[ -f "$WORK/temp/chatgpt-personal.failure1/build.log" && -f "$WORK/temp/chatgpt-personal.buildon1/build.log" ]]

# Log-archive failure must preserve the entire successful workspace.
mkdir -p "$WORK/log-blocked" "$WORK/temp/chatgpt-personal.logfail1"
touch "$WORK/log-blocked/Library" "$WORK/temp/chatgpt-personal.logfail1/.chatgpt-personal-build"
echo diagnostic > "$WORK/temp/chatgpt-personal.logfail1/build.log"
HOME="$WORK/log-blocked" finish_build_workspace 0 install "$WORK/temp/chatgpt-personal.logfail1" "$WORK/temp" > "$WORK/archive-failure.out" 2>&1
[[ -f "$WORK/temp/chatgpt-personal.logfail1/build.log" ]]

# Run the real installer logic against a fake HOME. Only code signing, process
# inspection, platform check and verification are mocked; no GUI/app is launched.
project="$WORK/project"
mkdir -p "$project" "$WORK/bin" "$WORK/home/Applications"
ditto "$ROOT/lib" "$project/lib"
echo 'retention_processes() { :; }' >> "$project/lib/retention.sh"
source_app="$WORK/source.app"; make_app "$source_app" source
stage="$WORK/stage/ChatGPT Personal.app"; make_app "$stage" 2
setkey "$stage" PersonalSourceInfoSHA256 "$(shasum -a 256 "$source_app/Contents/Info.plist" | awk '{print $1}')"
cat >> "$project/lib/common.sh" <<OVERRIDES
SOURCE='$source_app'
LSREGISTER=/usr/bin/true
platform() { :; }
not_running() { :; }
OVERRIDES
cat > "$project/verify.sh" <<'VERIFY'
#!/bin/bash
set -euo pipefail
[[ -f "$2/Contents/Info.plist" ]]
if [[ "$2" == "$HOME/Applications/ChatGPT Personal.app" && -f "$HOME/fail-final" ]]; then exit 23; fi
VERIFY
cat > "$WORK/bin/codesign" <<'SIGN'
#!/bin/bash
exit 0
SIGN
chmod +x "$project/verify.sh" "$WORK/bin/codesign"
make_app "$WORK/home/Applications/ChatGPT Personal.app" 1
make_app "$WORK/home/Applications/.chatgpt-personal.old00001/Previous ChatGPT Personal.app" 0
make_app "$WORK/home/Applications/.chatgpt-personal.old00002/Previous ChatGPT Personal.app" 0
mkdir -p "$WORK/home/Applications/.chatgpt-personal.unknown1"
echo keep > "$WORK/home/Applications/.chatgpt-personal.unknown1/private-data"
env HOME="$WORK/home" PATH="$WORK/bin:$PATH" /bin/bash "$project/lib/install-bundle.sh" "$stage" > "$WORK/success.log" 2>&1
count=$(find "$WORK/home/Applications" -name 'Previous ChatGPT Personal.app' -type d | wc -l | tr -d ' ')
[[ "$count" == 1 ]] || fail "Expected one rollback, found $count"
[[ $(get "$WORK/home/Applications/ChatGPT Personal.app" PersonalSourceBundleVersion) == 2 ]]
[[ -f "$WORK/home/Applications/.chatgpt-personal.unknown1/private-data" ]]
[[ -n $(find "$WORK/home/Library/Logs/ChatGPT-Personal/builds" -name install.log -print) ]]
# An installer must not remove a lock owned by a different invocation.
mkdir "$WORK/home/Applications/.chatgpt-personal-install.lock"
if env HOME="$WORK/home" PATH="$WORK/bin:$PATH" /bin/bash "$project/lib/install-bundle.sh" "$stage" > "$WORK/locked.log" 2>&1; then fail 'Existing lock ignored'; fi
[[ -d "$WORK/home/Applications/.chatgpt-personal-install.lock" ]] || fail 'Foreign lock was removed'
rmdir "$WORK/home/Applications/.chatgpt-personal-install.lock"
# Failed final verification restores the old app and retains failed diagnostics.
setkey "$stage" PersonalSourceBundleVersion 3
touch "$WORK/home/fail-final"
if env HOME="$WORK/home" PATH="$WORK/bin:$PATH" /bin/bash "$project/lib/install-bundle.sh" "$stage" > "$WORK/failure.log" 2>&1; then fail 'Failure was ignored'; fi
[[ $(get "$WORK/home/Applications/ChatGPT Personal.app" PersonalSourceBundleVersion) == 2 ]] || fail 'Previous app was not restored'
[[ -n $(find "$WORK/home/Applications" -name 'Rejected ChatGPT Personal.app' -print) ]] || fail 'Failed app diagnostics lost'
[[ -d "$WORK/stage" ]]
echo "Retention and installation rollback tests passed ($WORK)"
