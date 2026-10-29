#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-cli-test.XXXXXXXX")
WORK=$(cd "$WORK" && pwd)
mkdir -p "$WORK/home" "$WORK/bin" "$WORK/support/bin"
cp "$ROOT/bin/chatgpt-personal" "$WORK/support/bin/"
cp "$ROOT/VERSION" "$WORK/support/"
cat > "$WORK/support/update.sh" <<'SH'
#!/bin/bash
printf 'update: <%s>\n' "$@"
SH
cat > "$WORK/support/install-autoupdate.sh" <<'SH'
#!/bin/bash
printf '%s\n' "$PERSONAL_UPDATE_COMMAND"
SH
chmod +x "$WORK/support/"*.sh
ln -s ../support/bin/chatgpt-personal "$WORK/bin/chatgpt-personal"
cli="$WORK/bin/chatgpt-personal"
[[ $(HOME="$WORK/home" "$cli" --version) == "chatgpt-personal $(cat "$ROOT/VERSION")" ]]
[[ $("$cli" update --force) == 'update: <--force>' ]]
[[ $("$cli" autoupdate install) == "$cli" ]]
if "$cli" invalid >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$WORK/home/.codex-personal" && ! -e "$WORK/home/Applications" ]]
echo "CLI symlink, dispatch and stable updater path checks passed ($WORK)"
