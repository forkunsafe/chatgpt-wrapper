# ChatGPT Personal

An independent personal instance alongside your work account. Unofficial community tooling; not affiliated with OpenAI. This repository distributes only the wrapper source, never the ChatGPT app or its artwork.

Builds `~/Applications/ChatGPT Personal.app` from `/Applications/ChatGPT.app`, preserving its bundle identifier (`com.openai.codex`). The official bundle is only read. Personal data is never copied into a bundle or reset.

The Go launcher replaces itself with the preserved original executable using `exec`. Finder, Dock, Spotlight and `open` therefore pass through the same launcher without a terminal or waiting parent process. It sets `CODEX_HOME=$HOME/.codex-personal` and enforces `--user-data-dir=$HOME/Library/Application Support/ChatGPT-Personal`, removing caller profile overrides and preserving other arguments. HOME is unchanged. Chromium's separate data directory provides independent browser sessions and single-instance locks; CODEX_HOME separately isolates Codex configuration, credentials and sessions.

## Requirements and installation

### Homebrew (recommended)

Install the official ChatGPT app at `/Applications/ChatGPT.app` and Apple Command Line Tools (`xcode-select --install`) first, then:

```sh
brew install forkunsafe/tap/chatgpt-wrapper
chatgpt-personal install
chatgpt-personal open
chatgpt-personal verify
```

Homebrew installs the tools and Go dependency; the second command builds your local Personal copy. Quit Personal before rebuilding. The app lives at `~/Applications/ChatGPT Personal.app`: keep it there, launch it from Spotlight/Finder, or pin it to the Dock. The installed app runs without Homebrew or Go.

```sh
brew upgrade chatgpt-wrapper       # update wrapper tools, without touching your app/data
chatgpt-personal update            # rebuild from the current official app when needed
chatgpt-personal update --force    # also apply wrapper changes at the same app version
chatgpt-personal autoupdate install
chatgpt-personal autoupdate uninstall
```

The optional agent uses the stable Homebrew command path across formula upgrades. If migrating an existing source-checkout agent, uninstall that agent and install it again using the command above. `brew uninstall chatgpt-wrapper` removes tooling only; to remove Personal too, run `chatgpt-personal uninstall` first. Both preserve all account data.

### From source

Apple Silicon macOS, the official ChatGPT app, Go (https://go.dev/dl/) and Apple Command Line Tools (`xcode-select --install`). Go and the tiny AppKit icon helper are needed only at build time; the installed app needs neither Go nor Swift tooling. No dependencies are downloaded or installed automatically.

```sh
./install.sh --build-only  # build and verify a temporary bundle; no installation
./install.sh               # build, verify, then install
./verify.sh
open "$HOME/Applications/ChatGPT Personal.app"
./verify.sh                # also verifies running main process arguments/environment
```

Quit Personal before installation or rebuild. The scripts inspect both profile arguments and executable paths inside the installed Personal bundle, including helpers; they fail closed if process inspection is unavailable. They never kill processes. Existing profile directories are preserved, including their contents and permissions. Missing directories are created.

Each build starts with a fresh `ditto` copy. The original CFBundleExecutable is read from Info.plist and renamed once in that fresh copy. The original icon is read from CFBundleIconFile; a purple P badge is rendered into a full iconset and converted with `iconutil`. The app's dynamic `CodexAppIconBaseName` icon is also badged. Supply `assets/Personal.icns` to override generation. Only copied presentation metadata, launcher, icon assets and signatures are changed; CFBundleIdentifier stays intact.

When opening the **official** app from a terminal/agent that already has Personal's CODEX_HOME, clear that variable for the launch:

```sh
env -u CODEX_HOME open /Applications/ChatGPT.app
```

`open` inherits its caller's environment. An already running official process keeps its original environment: quit only the official app before this corrective launch. With CODEX_HOME unset, Codex uses `~/.codex` (and its current symlink target). The Personal launcher changes only its own process environment, never launchd's global environment. `verify.sh` detects an official process accidentally launched with Personal's CODEX_HOME. Upstream UI text may still say ChatGPT even though Finder/Dock metadata and icons are Personal.

## Updates

```sh
./update.sh
./update.sh --force
```

The installer/updater prints the official and installed Personal versions, numbered build/install stages, elapsed times and a status line every 10 seconds during slow commands or signature scanning. Detailed command output is written to `build.log` and `install.log` in the printed temporary workspace. Failures show the current stage, exit status, log location and the last log lines; successful installation prints the installed version and rollback path. When versions match, it explicitly reports that nothing changed.

The build-policy schema is also checked, so signing-policy fixes trigger a rebuild even when the source version is unchanged. Both official version keys are compared with `PersonalSourceBundleVersion` and `PersonalSourceShortVersionString`. A difference (including a downgrade) rebuilds from the current official bundle. Matching versions skip rebuilding unless forced. Force is also useful after changing project code or an icon. The official updater does not maintain this copy. If an upstream in-app updater replaces the Personal bundle, rerun `update.sh --force`; upstream updater behavior is not guaranteed.

```sh
./install-autoupdate.sh
./uninstall-autoupdate.sh
```

Optional current-user LaunchAgent checks hourly and at load. It invokes this project's updater and refuses rebuilds while any Personal process runs. Keep the project at its installed location. Go and Command Line Tools must remain available for automatic builds. Logs: `~/Library/Logs/ChatGPT-Personal/update.log`. The agent isn't installed by the normal installer.

## Safety, signatures and rollback

A verified temporary bundle is copied to a hidden temporary directory on the destination filesystem, verified again, and replaced with two renames. An installer lock and another process check protect replacement. The short rename window is not a fully atomic exchange. A failed move or final installed-app verification restores the previous app; rejected copies and diagnostics remain available.

After successful installed-app verification, **only the most recent previous installation** is retained under `~/Applications/.chatgpt-personal.*/Previous ChatGPT Personal.app`. Older recognized rollback slots are permanently removed, including slots from earlier installer versions. In-use copies and directories containing unexpected files are preserved with a message. Close Personal before restoring the printed rollback copy manually.

After successful normal installation, `build.log` and `install.log` are copied to a small per-run directory under `~/Library/Logs/ChatGPT-Personal/builds/`, and the marked temporary workspace (copied app, Go/Swift caches and icon intermediates) is deleted. A failure keeps the workspace for diagnosis. `--build-only` intentionally retains its output instead of installing/cleaning it. If log archiving fails, the workspace is retained. Cleanup never targets profile/Codex data or the official app. If interrupted, inspect any `.chatgpt-personal-install.lock` and backups before manually removing the empty lock.

Original entitlements are captured. Unchanged nested frameworks, plugins and helpers keep their original official signatures and entitlements: re-signing a privileged Codex helper ad-hoc makes macOS kill it, preventing startup policy loading. Only the renamed main executable and outer bundle/Go launcher are signed ad-hoc, from inside out, without `--deep` signing. Deep strict verification still checks the whole bundle.

The preserved main executable retains ordinary permissions and JIT entitlements, but removes Apple's application identifier, team identifier, push environment, associated domains, communication-notification entitlement and keychain access groups, which AMFI cannot validate for an ad-hoc executable. It adds `com.apple.security.cs.disable-library-validation` to load the original developer-signed frameworks without sharing their Team ID. The Go launcher has no entitlements. All payloads are compared against this explicit expected policy before installation. Original/effective payloads remain in failed or build-only workspaces; successful installations retain the command logs.

Ad-hoc signing removes Apple's developer signature/notarization identity. Keychain, push notifications, application groups, automation, TCC and privileged computer-use helpers may behave differently; retaining an entitlement doesn't grant Apple's privileges. Re-signing may prompt for permissions. Signature validity does not prove all upstream features work.

Unread indicators and Dock badges are not guaranteed. A missing unread indicator was also reproduced using the unmodified official executable with the same personal profile; the account/profile or upstream client behavior remains unresolved.

Verification checks metadata, icon, native launcher, preserved executable, source metadata, data directories and signatures. It checks CODEX_HOME and profile arguments if the preserved main executable is running, without printing other environment variables. The source Info.plist SHA-256 is recorded; builds compare source metadata/CDHash before/after, and verification checks the metadata hash when source versions match. This detects accidental source changes during the build, not arbitrary historical changes to every source file. Keeping the same bundle ID means LaunchServices, URL handlers and some OS-level services may share identity; use the full Personal app path when launching. Profile/Codex isolation does not promise isolation of Keychain, application groups or macOS permissions.

## Uninstall

```sh
./uninstall.sh
```

Moves only the Personal app and optional LaunchAgent to Trash, refusing while Personal is running. It preserves:

- `~/.codex-personal`
- `~/Library/Application Support/ChatGPT-Personal`
- `~/.codex-work` (never accessed by this project)

Data purge is deliberately unsupported. If you intentionally want to remove personal data, first quit Personal, back up these directories, and move the two personal directories to Trash yourself. Never remove `.codex-work` as part of this project's uninstall.

## Project files

`install.sh`, `update.sh`, `verify.sh`, `uninstall.sh`, optional LaunchAgent helpers, shared `lib/` scripts, `launcher/` (pure Go standard library) and `assets/icon.swift` (small AppKit command-line renderer, no Xcode project).

## Releases and license

`VERSION` versions the wrapper tools independently of the official app. `python3 scripts/package-release.py` creates a source-only archive, SHA-256 manifest and Homebrew formula under `dist/vVERSION/`, using an explicit file list. Releases exclude local diagnostics, account data, app bundles and Git history. See [LICENSE](LICENSE): Apache License 2.0 with Commons Clause 1.0 (source-available, not an OSI open-source license). The license covers this tooling; OpenAI's app and trademarks retain their respective ownership and terms.
