#!/usr/bin/env python3
"""Stage a fresh public checkout without internal Git history or local data."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
target = ROOT / "dist/publication/github-chatgpt-wrapper"
target.mkdir(parents=True, exist_ok=False)
files = ["README.md", "LICENSE", "VERSION", "install.sh",
         "update.sh", "verify.sh", "uninstall.sh", "install-autoupdate.sh",
         "uninstall-autoupdate.sh", "bin/chatgpt-personal", "assets/icon.swift",
         "launcher/go.mod", "launcher/main.go", "launcher/main_test.go",
         "packaging/chatgpt-wrapper.rb.in", "scripts/package-release.py",
         "scripts/stage-publication.py"]
files += [str(p.relative_to(ROOT)) for folder in ("lib", "tests")
          for p in sorted((ROOT / folder).glob("*.sh"))]
for filename in files:
    source = ROOT / filename
    if source.is_symlink() or not source.is_file():
        raise SystemExit(f"Not a regular publication file: {filename}")
    destination = target / filename
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
# Public build artifacts only; do not copy checkout-specific exclusions.
(target / ".gitignore").write_text(".DS_Store\n*.app/\n/launcher/launcher\ndist/\n")
print(target)
