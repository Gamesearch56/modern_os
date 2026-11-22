#!/usr/bin/env python3
# Paint one splash-colored frame when nothing is scanning out, then drop
# DRM master. The login screen turns the CRTC off as it exits, and an
# Intel laptop panel draws its firmware logo into that blank until the
# next compositor presents. Holding master until Hyprland has painted
# left the splash up forever, because Hyprland never got the device.
# This process keeps the buffer alive and is not the DRM master.
"""seat-cover: hold a frame across the compositor handoff."""

from __future__ import annotations

import ctypes
import errno
import fcntl
import mmap
import os
import sys
import time
from pathlib import Path

# Plymouth theme surface #141218. A black frame is another flash.
SPLASH = 0x00181214
HOLD_SECONDS = 20
AFTER_SOCKET = 2


def _ioc(direction: int, kind: int, nr: int, size: int) -> int:
    return (direction << 30) | (size << 16) | (kind << 8) | nr


def _io(nr: int) -> int:
    return _ioc(0, ord("d"), nr, 0)


def _iowr(nr: int, size: int) -> int:
    return _ioc(3, ord("d"), nr, size)


class ModeInfo(ctypes.Structure):
    _fields_ = [
        ("clock", ctypes.c_uint32),
        ("hdisplay", ctypes.c_uint16),
        ("hsync_start", ctypes.c_uint16),
        ("hsync_end", ctypes.c_uint16),
        ("htotal", ctypes.c_uint16),
        ("hskew", ctypes.c_uint16),
        ("vdisplay", ctypes.c_uint16),
        ("vsync_start", ctypes.c_uint16),
        ("vsync_end", ctypes.c_uint16),
        ("vtotal", ctypes.c_uint16),
        ("vscan", ctypes.c_uint16),
        ("vrefresh", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("type", ctypes.c_uint32),
        ("name", ctypes.c_char * 32),
    ]


class CardRes(ctypes.Structure):
    _fields_ = [
        ("fb_id_ptr", ctypes.c_uint64),
        ("crtc_id_ptr", ctypes.c_uint64),
        ("connector_id_ptr", ctypes.c_uint64),
        ("encoder_id_ptr", ctypes.c_uint64),
        ("count_fbs", ctypes.c_uint32),
        ("count_crtcs", ctypes.c_uint32),
        ("count_connectors", ctypes.c_uint32),
        ("count_encoders", ctypes.c_uint32),
        ("min_width", ctypes.c_uint32),
        ("max_width", ctypes.c_uint32),
        ("min_height", ctypes.c_uint32),
        ("max_height", ctypes.c_uint32),
    ]


class Crtc(ctypes.Structure):
    _fields_ = [
        ("set_connectors_ptr", ctypes.c_uint64),
        ("count_connectors", ctypes.c_uint32),
        ("crtc_id", ctypes.c_uint32),
        ("fb_id", ctypes.c_uint32),
        ("x", ctypes.c_uint32),
        ("y", ctypes.c_uint32),
        ("gamma_size", ctypes.c_uint32),
        ("mode_valid", ctypes.c_uint32),
        ("mode", ModeInfo),
    ]


class GetConnector(ctypes.Structure):
    _fields_ = [
        ("encoders_ptr", ctypes.c_uint64),
        ("modes_ptr", ctypes.c_uint64),
        ("props_ptr", ctypes.c_uint64),
        ("prop_values_ptr", ctypes.c_uint64),
        ("count_modes", ctypes.c_uint32),
        ("count_props", ctypes.c_uint32),
        ("count_encoders", ctypes.c_uint32),
        ("encoder_id", ctypes.c_uint32),
        ("connector_id", ctypes.c_uint32),
        ("connector_type", ctypes.c_uint32),
        ("connector_type_id", ctypes.c_uint32),
        ("connection", ctypes.c_uint32),
        ("mm_width", ctypes.c_uint32),
        ("mm_height", ctypes.c_uint32),
        ("subpixel", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
    ]


class FbCmd(ctypes.Structure):
    _fields_ = [
        ("fb_id", ctypes.c_uint32),
        ("width", ctypes.c_uint32),
        ("height", ctypes.c_uint32),
        ("pitch", ctypes.c_uint32),
        ("bpp", ctypes.c_uint32),
        ("depth", ctypes.c_uint32),
        ("handle", ctypes.c_uint32),
    ]


class CreateDumb(ctypes.Structure):
    _fields_ = [
        ("height", ctypes.c_uint32),
        ("width", ctypes.c_uint32),
        ("bpp", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("handle", ctypes.c_uint32),
        ("pitch", ctypes.c_uint32),
        ("size", ctypes.c_uint64),
    ]


class MapDumb(ctypes.Structure):
    _fields_ = [
        ("handle", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
        ("offset", ctypes.c_uint64),
    ]


SET_MASTER = _io(0x1E)
DROP_MASTER = _io(0x1F)
GETRESOURCES = _iowr(0xA0, ctypes.sizeof(CardRes))
GETCRTC = _iowr(0xA1, ctypes.sizeof(Crtc))
SETCRTC = _iowr(0xA2, ctypes.sizeof(Crtc))
GETCONNECTOR = _iowr(0xA7, ctypes.sizeof(GetConnector))
ADDFB = _iowr(0xAE, ctypes.sizeof(FbCmd))
CREATE_DUMB = _iowr(0xB2, ctypes.sizeof(CreateDumb))
MAP_DUMB = _iowr(0xB3, ctypes.sizeof(MapDumb))

CONNECTED = 1


def should_cover(active_crtcs: int) -> bool:
    """A CRTC that is already scanning out must be left alone."""
    return active_crtcs == 0


def splash_pixel() -> bytes:
    return SPLASH.to_bytes(4, "little")


def _ioctl(fd: int, request: int, buf: ctypes.Structure | None = None) -> None:
    if buf is None:
        fcntl.ioctl(fd, request)
    else:
        fcntl.ioctl(fd, request, buf)


def _resources(fd: int) -> tuple[list[int], list[int]]:
    res = CardRes()
    _ioctl(fd, GETRESOURCES, res)
    # Every non-zero count is copied. A null pointer for one of them is
    # EFAULT even when that list is not the one we came for.
    fbs = (ctypes.c_uint32 * max(res.count_fbs, 1))()
    crtcs = (ctypes.c_uint32 * max(res.count_crtcs, 1))()
    conns = (ctypes.c_uint32 * max(res.count_connectors, 1))()
    encs = (ctypes.c_uint32 * max(res.count_encoders, 1))()
    if res.count_fbs:
        res.fb_id_ptr = ctypes.addressof(fbs)
    if res.count_crtcs:
        res.crtc_id_ptr = ctypes.addressof(crtcs)
    if res.count_connectors:
        res.connector_id_ptr = ctypes.addressof(conns)
    if res.count_encoders:
        res.encoder_id_ptr = ctypes.addressof(encs)
    _ioctl(fd, GETRESOURCES, res)
    return list(crtcs[: res.count_crtcs]), list(conns[: res.count_connectors])


def _crtc_scanning(fd: int, crtc_id: int) -> bool:
    crtc = Crtc()
    crtc.crtc_id = crtc_id
    _ioctl(fd, GETCRTC, crtc)
    return crtc.mode_valid != 0 and crtc.fb_id != 0


def _first_mode(fd: int, connector_id: int) -> tuple[int, ModeInfo] | None:
    # count_modes of 0 force-probes and can blank the panel. Ask for one
    # mode so the kernel only reports what it already knows.
    scratch = ModeInfo()
    info = GetConnector()
    info.connector_id = connector_id
    info.count_modes = 1
    info.modes_ptr = ctypes.addressof(scratch)
    _ioctl(fd, GETCONNECTOR, info)
    if info.connection != CONNECTED or info.count_modes < 1:
        return None
    modes = (ModeInfo * info.count_modes)()
    info.modes_ptr = ctypes.addressof(modes)
    info.count_props = 0
    info.count_encoders = 0
    info.props_ptr = 0
    info.prop_values_ptr = 0
    info.encoders_ptr = 0
    _ioctl(fd, GETCONNECTOR, info)
    if info.count_modes < 1:
        return None
    return connector_id, modes[0]


def _cards() -> list[str]:
    dri = Path("/dev/dri")
    if not dri.is_dir():
        return []
    return sorted(str(p) for p in dri.glob("card[0-9]") if p.is_char_device())


def paint(fd: int, crtc_id: int, connector_id: int, mode: ModeInfo) -> int:
    """Program one frame and return the fd that keeps the buffer alive."""
    width = int(mode.hdisplay)
    height = int(mode.vdisplay)
    if width < 1 or height < 1:
        raise RuntimeError("mode has no size")
    _ioctl(fd, SET_MASTER)
    dumb = CreateDumb(height=height, width=width, bpp=32)
    _ioctl(fd, CREATE_DUMB, dumb)
    mapped = MapDumb(handle=dumb.handle)
    _ioctl(fd, MAP_DUMB, mapped)
    view = mmap.mmap(
        fd,
        dumb.size,
        mmap.MAP_SHARED,
        mmap.PROT_READ | mmap.PROT_WRITE,
        offset=mapped.offset,
    )
    try:
        pixel = splash_pixel()
        row = pixel * width
        pad = b"\x00" * (dumb.pitch - width * 4)
        for y in range(height):
            view.seek(y * dumb.pitch)
            view.write(row)
            if pad:
                view.write(pad)
    finally:
        view.close()
    fb = FbCmd(width=width, height=height, pitch=dumb.pitch, bpp=32, depth=24, handle=dumb.handle)
    _ioctl(fd, ADDFB, fb)
    conn = ctypes.c_uint32(connector_id)
    crtc = Crtc()
    crtc.set_connectors_ptr = ctypes.addressof(conn)
    crtc.count_connectors = 1
    crtc.crtc_id = crtc_id
    crtc.fb_id = fb.fb_id
    crtc.mode_valid = 1
    crtc.mode = mode
    _ioctl(fd, SETCRTC, crtc)
    _ioctl(fd, DROP_MASTER)
    print(f"seat-cover: painted {width}x{height} and dropped master", file=sys.stderr)
    return fd


def _wait_for_compositor() -> None:
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    root = Path(runtime) / "hypr" if runtime else None
    start = time.monotonic()
    seen: float | None = None
    while time.monotonic() - start < HOLD_SECONDS:
        if seen is None and root is not None and any(root.glob("*")):
            seen = time.monotonic()
        if seen is not None and time.monotonic() - seen >= AFTER_SOCKET:
            return
        time.sleep(0.1)


def _hold_fd(fd: int) -> None:
    # Keep the buffer fd above the stdio slots. Replacing stdin must not
    # close the scanout buffer.
    held = fcntl.fcntl(fd, fcntl.F_DUPFD, 100)
    os.close(fd)
    pid = os.fork()
    if pid > 0:
        os.close(held)
        return
    os.setsid()
    try:
        null = os.open("/dev/null", os.O_RDONLY)
        os.dup2(null, 0)
        if null > 2:
            os.close(null)
        _wait_for_compositor()
    finally:
        os.close(held)
        os._exit(0)


def hold() -> int:
    if os.environ.get("MODERN_SEAT_COVER") == "0":
        return 0
    for path in _cards():
        fd: int | None = None
        try:
            fd = os.open(path, os.O_RDWR | os.O_CLOEXEC)
            crtcs, conns = _resources(fd)
            active = sum(1 for crtc in crtcs if _crtc_scanning(fd, crtc))
            if not should_cover(active):
                print("seat-cover: display already scanning", file=sys.stderr)
                os.close(fd)
                return 0
            chosen = None
            for conn in conns:
                chosen = _first_mode(fd, conn)
                if chosen is not None:
                    break
            if chosen is None or not crtcs:
                os.close(fd)
                continue
            connector_id, mode = chosen
            painted = False
            last_exc: OSError | None = None
            for crtc in crtcs:
                try:
                    paint(fd, crtc, connector_id, mode)
                    painted = True
                    break
                except OSError as exc:
                    last_exc = exc
                    try:
                        _ioctl(fd, DROP_MASTER)
                    except OSError:
                        pass
            if not painted:
                raise last_exc or RuntimeError("no crtc accepted the frame")
            _hold_fd(fd)
            return 0
        except Exception as exc:
            print(f"seat-cover: skipped {path} ({exc})", file=sys.stderr)
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
    print("seat-cover: no display to cover", file=sys.stderr)
    return 0


def self_test() -> int:
    if ctypes.sizeof(ModeInfo) != 68 or ctypes.sizeof(Crtc) != 104:
        print("seat-cover: mode struct size drifted", file=sys.stderr)
        return 1
    if ctypes.sizeof(GetConnector) != 80 or ctypes.sizeof(CardRes) != 64:
        print("seat-cover: connector struct size drifted", file=sys.stderr)
        return 1
    if not should_cover(0) or should_cover(1):
        print("seat-cover: cover decision is wrong", file=sys.stderr)
        return 1
    if ctypes.sizeof(CreateDumb) != 32 or ctypes.sizeof(MapDumb) != 16 or ctypes.sizeof(FbCmd) != 28:
        print("seat-cover: buffer struct size drifted", file=sys.stderr)
        return 1
    if splash_pixel() != bytes((0x14, 0x12, 0x18, 0x00)):
        print("seat-cover: splash pixel is not #141218", file=sys.stderr)
        return 1
    probed = False
    for path in _cards():
        try:
            fd = os.open(path, os.O_RDWR | os.O_CLOEXEC)
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EPERM):
                continue
            print(f"seat-cover: probe {path} failed ({exc})", file=sys.stderr)
            return 1
        try:
            crtcs, _conns = _resources(fd)
            for crtc in crtcs:
                _crtc_scanning(fd, crtc)
            probed = True
            break
        except OSError as exc:
            if exc.errno in (errno.EACCES, errno.EPERM, errno.EBUSY):
                continue
            print(f"seat-cover: probe {path} failed ({exc})", file=sys.stderr)
            return 1
        finally:
            os.close(fd)
    if not probed:
        print("seat-cover: no card to probe; struct checks passed", file=sys.stderr)
    else:
        print("seat-cover: read-only probe ok", file=sys.stderr)
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "hold"
    if cmd == "--self-test":
        return self_test()
    if cmd == "hold":
        return hold()
    print(f"seat-cover: unknown command {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
