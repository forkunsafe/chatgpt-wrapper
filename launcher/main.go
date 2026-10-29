package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

// realName is embedded at build time from the official CFBundleExecutable.
var realName string

func main() {
	home, err := os.UserHomeDir()
	if err != nil || !filepath.IsAbs(home) {
		fail(fmt.Errorf("cannot resolve absolute home directory: %v", err))
	}
	self, err := os.Executable()
	if err != nil {
		fail(err)
	}
	self, err = filepath.EvalSymlinks(self)
	if err != nil {
		fail(err)
	}
	if realName == "" || filepath.Base(realName) != realName {
		fail(fmt.Errorf("invalid original executable"))
	}
	real := filepath.Join(filepath.Dir(self), realName)
	args := []string{real, "--user-data-dir=" + filepath.Join(home, "Library", "Application Support", "ChatGPT-Personal")}
	// Caller-supplied profile overrides must never defeat personal isolation.
	for i := 1; i < len(os.Args); i++ {
		a := os.Args[i]
		if a == "--user-data-dir" {
			if i+1 < len(os.Args) {
				i++
			}
			continue
		}
		if strings.HasPrefix(a, "--user-data-dir=") {
			continue
		}
		args = append(args, a)
	}
	if err := os.Setenv("CODEX_HOME", filepath.Join(home, ".codex-personal")); err != nil {
		fail(err)
	}
	// Replace this process: no waiting launcher, no detached child, same LaunchServices PID.
	fail(syscall.Exec(real, args, os.Environ()))
}
func fail(err error) { fmt.Fprintln(os.Stderr, "ChatGPT Personal:", err); os.Exit(1) }
