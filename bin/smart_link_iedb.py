#!/usr/bin/env python3
import argparse
import os
import sys
import tempfile
from pathlib import Path
from typing import List, Tuple

MAX_LEN = 57  # path length limit

COMMON_ROOTS = [
    "/scratch", "/localscratch", "/local", "/var/tmp",
    "/mnt", "/mnt1", "/mnt2", "/nvme", "/ephemeral",
    "/efs", "/fsx", "/lustre", "/gpfs",
]

ENV_VARS = ["SLURM_TMPDIR", "TMPDIR", "LOCAL_SCRATCH", "LSCRATCH", "SCRATCH"]

def real_len(p: Path) -> int:
    try:
        return len(p.resolve(strict=True).as_posix())
    except FileNotFoundError:
        return len(p.as_posix())

def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)

def same_filesystem(a: Path, b: Path) -> bool:
    try:
        return os.stat(a).st_dev == os.stat(b).st_dev
    except FileNotFoundError:
        return False

def candidate_roots() -> List[Path]:
    roots = []
    for ev in ENV_VARS:
        v = os.environ.get(ev)
        if v:
            roots.append(Path(v))
    roots.extend(Path(r) for r in COMMON_ROOTS)
    roots.append(Path.cwd())
    return [r for r in roots if r.exists() and os.access(r, os.W_OK)]

def make_very_short(root: Path) -> Path | None:
    """
    Create a brand-new, very short, unique directory under `root`.
    Never touches existing content. Ensures total path < MAX_LEN.
    """
    for prefix in ("i.", "x.", ".i.", ".x."):
        try:
            d = Path(tempfile.mkdtemp(prefix=prefix, dir=root))
            if real_len(d) < MAX_LEN:
                return d.resolve()
            # too long -> remove empty dir and try next prefix
            try:
                d.rmdir()
            except Exception:
                pass
        except Exception:
            # cannot create here; try next
            pass
    return None

def hardlink_tree(src: Path, dst: Path) -> None:
    """
    Hardlink src/* into dst/. Fails if not possible (e.g., different FS).
    Does not remove or reuse existing dirs; dst is assumed empty/new.
    """
    ensure_dir(dst)
    if not same_filesystem(src, dst):
        raise RuntimeError("hardlink across filesystems is not possible")

    for root, dirs, files in os.walk(src):
        rel = Path(root).relative_to(src)
        target_dir = dst / rel
        ensure_dir(target_dir)
        for d in dirs:
            ensure_dir(target_dir / d)
        for f in files:
            s = Path(root) / f
            t = target_dir / f
            # link only regular files
            if s.is_file():
                os.link(s, t)

def pick_target(src: Path) -> Tuple[Path, str]:
    """
    Decide target and mode.
    - If src path already short: return (src, "original")
    - Else: create a fresh short dir under good roots and return (target, "hardlink")
    """
    src_real = src.resolve()
    if real_len(src_real) < MAX_LEN:
        return src_real, "original"

    # Prefer roots that allow us to hardlink (same filesystem) — best effort:
    roots = candidate_roots()
    # try to find same-FS first
    for r in roots:
        d = make_very_short(r)
        if d and same_filesystem(src_real, d):
            return d, "hardlink"

    # otherwise still make a short dir (will fail on hardlink step with clear error)
    for r in roots:
        d = make_very_short(r)
        if d:
            return d, "hardlink"

    raise RuntimeError("No short writable directory (<57 chars) could be created")

def main():
    ap = argparse.ArgumentParser(description="Ensure IEDB install path is short, using hardlinks only.")
    ap.add_argument("--src", required=True, help="Path to existing IEDB directory")
    args = ap.parse_args()

    src = Path(args.src)
    if not src.is_dir():
        print(f"SMART_LINK_IEDB: source not a directory: {src}", file=sys.stderr)
        sys.exit(1)

    target, mode = pick_target(src)

    if mode == "original":
        # Just print results; no changes on disk
        print(target.as_posix())
        print("original")
        return

    # Hardlink-only materialization
    try:
        hardlink_tree(src, target)
    except Exception as e:
        print(
            "SMART_LINK_IEDB: hardlinking failed: "
            f"{e}. Provide a scratch path on the same filesystem or bind-mount a short path.",
            file=sys.stderr,
        )
        sys.exit(2)

    print(target.as_posix())
    print("hardlink")

if __name__ == "__main__":
    main()
