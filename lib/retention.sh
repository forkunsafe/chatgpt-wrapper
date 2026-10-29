#!/bin/bash
# Cleanup is deliberately limited to our own marked build directories and
# legacy/current rollback slots containing exactly one recognized app.
archive_build_logs() {
 local workspace=$1 destination file
 mkdir -p "$HOME/Library/Logs/ChatGPT-Personal/builds" || return 1
 destination=$(mktemp -d "$HOME/Library/Logs/ChatGPT-Personal/builds/run.XXXXXXXX") || return 1
 for file in build.log install.log; do
  if [[ -f "$workspace/$file" ]]; then cp "$workspace/$file" "$destination/$file" || return 1; fi
 done
 echo "Saved logs: $destination"
}
remove_build_workspace() {
 local workspace=$1 parent=$2
 [[ -d "$workspace" && ! -L "$workspace" && "$(dirname "$workspace")" == "$parent" && "$(basename "$workspace")" == chatgpt-personal.???????? && -f "$workspace/.chatgpt-personal-build" && ! -L "$workspace/.chatgpt-personal-build" ]] || return 1
 rm -rf -- "$workspace"
}
retention_processes() { /bin/ps -axww -o comm=; }
prune_rollback_slots() {
 local parent=$1 keep=$2 candidate child app recognized count removed=0 process_list
 process_list=$(retention_processes) || return 1
 [[ -d "$keep/Previous ChatGPT Personal.app" && ! -L "$keep" ]] || return 1
 for candidate in "$parent"/.chatgpt-personal.????????; do
  [[ -d "$candidate" && ! -L "$candidate" && "$candidate" != "$keep" ]] || continue
  if [[ "$process_list" == *"$candidate/"* ]]; then
   echo "In-use backup preserved: $candidate"; continue
  fi
  app="$candidate/Previous ChatGPT Personal.app"
  [[ -d "$app" && ! -L "$app" ]] || continue
  [[ $(get "$app" CFBundleDisplayName || true) == 'ChatGPT Personal' ]] || continue
  recognized=true; count=0
  for child in "$candidate"/* "$candidate"/.[!.]* "$candidate"/..?*; do
   [[ -e "$child" || -L "$child" ]] || continue
   count=$((count+1))
   [[ "$child" == "$app" ]] || recognized=false
  done
  if $recognized && [[ $count == 1 ]]; then
   rm -rf -- "$candidate" || return 1
   removed=$((removed+1))
  else echo "Unrecognized backup contents preserved: $candidate"; fi
 done
 echo "Removed $removed older rollback copies; retained: $keep/Previous ChatGPT Personal.app"
}

finish_build_workspace() {
 local status=$1 mode=$2 workspace=$3 parent=$4
 if [[ $status != 0 ]]; then
  echo "Build failed or interrupted; diagnostics retained: $workspace" >&2
  echo "Log: $workspace/build.log" >&2
 elif [[ "$mode" == build-only ]]; then
  echo "Build-only workspace retained: $workspace"
 elif archive_build_logs "$workspace"; then
  if remove_build_workspace "$workspace" "$parent"; then
   echo 'Temporary app and compiler caches removed.'
  else echo "Warning: could not clean build workspace: $workspace" >&2; fi
 else echo "Warning: log archive failed; build workspace retained: $workspace" >&2
 fi
}
