#!/usr/bin/env python3
import argparse
import errno
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import List, Tuple

MAX_LEN = 52  # path length limit

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
    roots: List[Path] = []
    for ev in ENV_VARS:
        v = os.environ.get(ev)
        if v:
            roots.append(Path(v))
    roots.extend(Path(r) for r in COMMON_ROOTS)
    roots.append(Path.cwd())
    return [r for r in roots if r.exists() and os.access(r, os.W_OK)]

def ancestor_roots(src: Path) -> List[Path]:
    roots: List[Path] = []
    seen = set()
    cur = src.resolve().parent  # start at parent
    while True:
        if cur is None:
            break
        sp = cur.as_posix()
        if sp not in seen and cur.exists() and os.access(cur, os.W_OK):
            roots.append(cur)
            seen.add(sp)
        if cur.parent == cur:  # reached root
            break
        cur = cur.parent
    return roots

def make_very_short(root: Path) -> Path | None:
    """Create a new, short, unique directory under `root` (< MAX_LEN)."""
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
            pass
    return None

def link_or_copy_tree(src: Path, dst: Path) -> str:
    """
    Attempt to hardlink src/* into dst/.
    Falls back to copy per file on EPERM/EACCES/EXDEV.
    Returns "hardlink" if everything linked, otherwise "copy".
    """
    ensure_dir(dst)
    all_linked = True

    # If obviously not same FS, we’ll copy everything (fast path)
    if not same_filesystem(src, dst):
        shutil.copytree(src, dst, dirs_exist_ok=True)
        return "copy"

    for root, dirs, files in os.walk(src):
        rel = Path(root).relative_to(src)
        target_dir = dst / rel
        ensure_dir(target_dir)
        for d in dirs:
            ensure_dir(target_dir / d)
        for f in files:
            s = Path(root) / f
            t = target_dir / f
            if not s.is_file():
                continue
            try:
                os.link(s, t)
            except OSError as e:
                if e.errno in (errno.EPERM, errno.EACCES, errno.EXDEV):
                    shutil.copy2(s, t)
                    all_linked = False
                else:
                    raise
    return "hardlink" if all_linked else "copy"

def pick_target(src: Path) -> Tuple[Path, str]:
    """
    Decide target and initial mode.
    - If src path already short: return (src, "original")
    - Else: try ancestors first (same FS), then env/common roots.
    For non-original, we’ll materialize and then report "hardlink" or "copy".
    """
    src_real = src.resolve()
    if real_len(src_real) < MAX_LEN:
        return src_real, "original"

    # 1) Try ancestors (same FS most likely)
    for r in ancestor_roots(src_real):
        d = make_very_short(r)
        if d:
            return d, "materialize"

    # 2) Try env/common roots
    for r in candidate_roots():
        d = make_very_short(r)
        if d:
            return d, "materialize"

    raise RuntimeError("No short writable directory (<57 chars) could be created")

def main():
    ap = argparse.ArgumentParser(
        description="Ensure IEDB path is short; hardlink when possible, else copy."
    )
    ap.add_argument("--src", required=True, help="Path to existing IEDB directory")
    args = ap.parse_args()

    src = Path(args.src)
    if not src.is_dir():
        print(f"SMART_LINK_IEDB: source not a directory: {src}", file=sys.stderr)
        sys.exit(1)

    target, mode = pick_target(src)

    if mode == "original":
        print(target.as_posix())
        print("original")
        return

    # Materialize (link or copy)
    try:
        final_mode = link_or_copy_tree(src, target)
    except Exception as e:
        print(
            "SMART_LINK_IEDB: materialization failed: "
            f"{e}. Provide a writable short path or bind-mount a short path.",
            file=sys.stderr,
        )
        sys.exit(2)

    print(target.as_posix())
    print(final_mode)  # "hardlink" or "copy"

if __name__ == "__main__":
    main()
