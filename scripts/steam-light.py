#!/usr/bin/env python3
"""Light Steam profile for a slow processor.

Sets the library performance keys and caps background shader work.
Prints nothing from the files it edits. `apply` records a marker;
`clear` restores only when that marker is present.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

MARK = "# modern:steamLight\n"
SHADER_LINE = "unShaderBackgroundProcessingThreads 1\n"
BLOCK_RE = re.compile(r"# modern:steamLight\nunShaderBackgroundProcessingThreads \d+\n")

LIGHT_LOCAL = {
    "LibraryLowPerfMode": "1",
    "LibraryLowBandwidthMode": "1",
    "LibraryDisableCommunityContent": "1",
}
RICH_LOCAL = {key: "0" for key in LIGHT_LOCAL}
LOCAL_ANCHORS = ("FavoriteServersLastUpdateTime", "LastPlayedTimesSyncTime")

LIGHT_REG = {"GPUAccelWebViewsV3": "0", "GPUAccelWebViews": "0"}
RICH_REG = {key: "1" for key in LIGHT_REG}
REG_ANCHORS = ("AutoLoginUser", "CompletedOOBEStage1")


def _state_file() -> Path:
    base = os.environ.get("MODERN_STATE_DIR")
    if not base:
        base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "modern" / "steam-light"


def steam_root() -> Path | None:
    override = os.environ.get("MODERN_STEAM_ROOT")
    if override:
        path = Path(override)
        return path if path.is_dir() else None
    home = Path.home()
    for candidate in (home / ".steam" / "steam", home / ".local" / "share" / "Steam"):
        if candidate.is_dir():
            return candidate
    return None


def _set_key(text: str, key: str, value: str, anchors: tuple[str, ...]) -> str:
    found = re.compile(
        r'^([ \t]*)"' + re.escape(key) + r'"[ \t]+"[^"]*"',
        re.M,
    )
    match = found.search(text)
    if match:
        return found.sub(rf'\1"{key}"\t\t"{value}"', text, count=1)
    for anchor in anchors:
        spot = re.search(r'^([ \t]*)"' + re.escape(anchor) + r'"', text, re.M)
        if not spot:
            continue
        indent = spot.group(1)
        line = f'{indent}"{key}"\t\t"{value}"\n'
        return text[: spot.start()] + line + text[spot.start() :]
    return text


def _rewrite(path: Path, keys: dict[str, str], anchors: tuple[str, ...]) -> None:
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    updated = text
    for key, value in keys.items():
        updated = _set_key(updated, key, value, anchors)
    if updated != text:
        path.write_text(updated, encoding="utf-8")


def _shader_cfg(root: Path, enabled: bool) -> None:
    path = root / "steam_dev.cfg"
    text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
    text = BLOCK_RE.sub("", text)
    if enabled:
        if text and not text.endswith("\n"):
            text += "\n"
        text += MARK + SHADER_LINE
        path.write_text(text, encoding="utf-8")
        return
    if text.strip():
        path.write_text(text, encoding="utf-8")
    elif path.is_file():
        path.unlink()


def _local_files(root: Path) -> list[Path]:
    userdata = root / "userdata"
    if not userdata.is_dir():
        return []
    return sorted(userdata.glob("*/config/localconfig.vdf"))


def apply() -> int:
    root = steam_root()
    if root is None:
        return 0
    for path in _local_files(root):
        _rewrite(path, LIGHT_LOCAL, LOCAL_ANCHORS)
    _rewrite(root / "registry.vdf", LIGHT_REG, REG_ANCHORS)
    _shader_cfg(root, True)
    marker = _state_file()
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text("1\n", encoding="utf-8")
    return 0


def clear() -> int:
    marker = _state_file()
    if not marker.is_file():
        return 0
    root = steam_root()
    if root is not None:
        for path in _local_files(root):
            _rewrite(path, RICH_LOCAL, LOCAL_ANCHORS)
        _rewrite(root / "registry.vdf", RICH_REG, REG_ANCHORS)
        _shader_cfg(root, False)
    marker.unlink(missing_ok=True)
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "apply":
        return apply()
    if cmd == "clear":
        return clear()
    print("usage: steam-light.py apply|clear", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
