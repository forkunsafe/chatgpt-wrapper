package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestLauncherExecIsolation(t *testing.T) {
	dir := t.TempDir()
	home := filepath.Join(dir, "home with spaces")
	if err := os.MkdirAll(home, 0700); err != nil {
		t.Fatal(err)
	}
	launcher := filepath.Join(dir, "PersonalLauncher")
	build := exec.Command("go", "build", "-ldflags", "-X main.realName=fixture.real", "-o", launcher, ".")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	// A harmless stand-in executable exercises actual exec, inherited environment and arguments.
	fixture := "#!/bin/sh\nprintf '%s\\n' \"$HOME\" \"$CODEX_HOME\" \"$PERSONAL_TEST_SENTINEL\" \"$@\"\n"
	if err := os.WriteFile(filepath.Join(dir, "fixture.real"), []byte(fixture), 0700); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(launcher, "--user-data-dir=/wrong", "--user-data-dir", "/also-wrong", "--other", "argument with spaces")
	cmd.Env = append(os.Environ(), "HOME="+home, "CODEX_HOME=/wrong", "PERSONAL_TEST_SENTINEL=preserved")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("launch: %v: %s", err, out)
	}
	want := strings.Join([]string{home, filepath.Join(home, ".codex-personal"), "preserved", "--user-data-dir=" + filepath.Join(home, "Library", "Application Support", "ChatGPT-Personal"), "--other", "argument with spaces", ""}, "\n")
	if string(out) != want {
		t.Fatalf("got %q, want %q", out, want)
	}
}
