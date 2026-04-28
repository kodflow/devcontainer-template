#!/usr/bin/env python3
"""Emit a deterministic per-file sha256 manifest for the features tree.

Used by CI (.github/workflows/docker-images.yml) to produce
image-template-files.json, embedded into the image at
/etc/devcontainer-template/.template-files.json. Consumed at runtime by
images/hooks/shared/sync-features.sh (_sync_via_manifest) to tell
consumer-modified files from previously-shipped pristine ones, so that
the postStart 3-way sync only overwrites untouched files.

Tracking issue: kodflow/devcontainer-template#334.

Usage:
    build-features-manifest.py <features_dir> <commit_short> <iso8601_utc>
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def build_manifest(root: Path, commit: str, generated_at: str) -> dict:
    files: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        files[rel] = f"sha256:{digest}"
    return {
        "version": 1,
        "commit": commit,
        "generated_at": generated_at,
        "files": files,
    }


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    root = Path(argv[1])
    if not root.is_dir():
        print(f"error: features dir not found: {root}", file=sys.stderr)
        return 1
    manifest = build_manifest(root, argv[2], argv[3])
    json.dump(manifest, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
