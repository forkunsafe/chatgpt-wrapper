#!/usr/bin/env python3
"""Create a deterministic source-only release using an explicit file allowlist."""
import hashlib
import io
from pathlib import Path
import re
import tarfile
import gzip
import sys

ROOT = Path(__file__).resolve().parent.parent
version = (ROOT / "VERSION").read_text().strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("VERSION must be a stable semantic version")
output = Path(sys.argv[1]) if len(sys.argv) == 2 else ROOT / "dist" / f"v{version}"
output.mkdir(parents=True, exist_ok=False)
# No app bundles, diagnostics, Git history, credentials or upstream icon assets.
files = ["README.md", "LICENSE", "VERSION", "bin/chatgpt-personal",
         "install.sh", "update.sh", "verify.sh", "uninstall.sh",
         "install-autoupdate.sh", "uninstall-autoupdate.sh", "assets/icon.swift",
         "launcher/go.mod", "launcher/main.go", "launcher/main_test.go"]
files += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "lib").glob("*.sh"))]
files += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "tests").glob("*.sh"))]
name = f"chatgpt-wrapper-{version}.tar.gz"
with (output / name).open("wb") as raw:
    with gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as archive:
            for filename in sorted(files):
                path = ROOT / filename
                if path.is_symlink() or not path.is_file():
                    raise SystemExit(f"Not a regular release file: {filename}")
                data = path.read_bytes()
                info = tarfile.TarInfo(f"chatgpt-wrapper-{version}/{filename}")
                info.size = len(data)
                info.mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
                archive.addfile(info, io.BytesIO(data))
digest = hashlib.sha256((output / name).read_bytes()).hexdigest()
(output / "SHA256SUMS").write_text(f"{digest}  {name}\n")
formula = (ROOT / "packaging/chatgpt-wrapper.rb.in").read_text()
(output / "chatgpt-wrapper.rb").write_text(formula.replace("@VERSION@", version).replace("@SHA256@", digest))
print(f"Release: {output / name}\nSHA-256: {digest}")
