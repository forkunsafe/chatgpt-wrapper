#!/bin/bash
# Read-only process classification tests; no live processes/data are changed.
source "$(dirname "$0")/../lib/common.sh"
processes() {
 printf '%s\n' \
 '100 /Applications/ChatGPT.app/Contents/MacOS/ChatGPT --user-data-dir=/work' \
 "200 $APP/Contents/MacOS/ChatGPT.real --user-data-dir=$PROFILE" \
 "201 $APP/Contents/Frameworks/renderer" \
 "300 /other/ChatGPT --user-data-dir $PROFILE"
}
[[ $(personal_pids) == $'200\n201\n300' ]] || fail 'Incorrect personal process classification'
processes() { printf '%s\n' '100 /Applications/ChatGPT.app/Contents/MacOS/ChatGPT'; }
[[ -z $(personal_pids) ]] || fail 'Official instance falsely identified'
processes() { return 1; }
if personal_pids >/dev/null; then fail 'Process failure did not fail closed'; fi
echo 'Process safety tests passed'
