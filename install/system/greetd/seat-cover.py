#!/usr/bin/env python3
# Keep a splash frame across Plymouth's exit and across logout. Plymouth
# closes its device as it quits, which turns the panel off, and the login
# compositor does the same as it leaves. This laptop then draws its
# firmware picture. A page flip takes over a frame that is already
# scanning; programming the mode again retrains the link and shows that
# picture too. Holding master until Hyprland has painted left the splash
# up forever, because Hyprland never got the device. This process keeps
# the buffer alive and is not the DRM master.
"""seat-cover: hold a frame across the compositor handoff."""

from __future__ import annotations

import ctypes
import errno
import fcntl
import mmap
import os
import select
import subprocess
import sys
import time
from pathlib import Path

try:
    sys.stderr.reconfigure(line_buffering=True)
except (AttributeError, OSError):
    pass

# Plymouth theme surface #141218. A black frame is another flash.
SPLASH = 0x00181214
HOLD_SECONDS = 20
AFTER_SOCKET = 2
# The parent waits this long for the first frame, then lets Plymouth quit.
# Longer than that and the login screen sits behind the splash.
ADOPT_SECONDS = 1.5


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


class VBlank(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_uint32),
        ("sequence", ctypes.c_uint32),
        ("tval_sec", ctypes.c_int64),
        ("tval_usec", ctypes.c_int64),
    ]


WAIT_VBLANK = _iowr(0x3A, ctypes.sizeof(VBlank))
# Set when the splash frame was taken over without dropping master, so
# Plymouth's quit cannot turn the panel off before the login screen.
HELD_MASTER = False


class PageFlip(ctypes.Structure):
    _fields_ = [
        ("crtc_id", ctypes.c_uint32),
        ("fb_id", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("reserved", ctypes.c_uint32),
        ("user_data", ctypes.c_uint64),
    ]


class DrmEventVblank(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_uint32),
        ("length", ctypes.c_uint32),
        ("user_data", ctypes.c_uint64),
        ("tv_sec", ctypes.c_uint32),
        ("tv_usec", ctypes.c_uint32),
        ("sequence", ctypes.c_uint32),
        ("crtc_id", ctypes.c_uint32),
    ]


class GetEncoder(ctypes.Structure):
    _fields_ = [
        ("encoder_id", ctypes.c_uint32),
        ("encoder_type", ctypes.c_uint32),
        ("crtc_id", ctypes.c_uint32),
        ("possible_crtcs", ctypes.c_uint32),
        ("possible_clones", ctypes.c_uint32),
    ]


class GetProperty(ctypes.Structure):
    _fields_ = [
        ("values_ptr", ctypes.c_uint64),
        ("enum_blob_ptr", ctypes.c_uint64),
        ("prop_id", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("name", ctypes.c_char * 32),
        ("count_values", ctypes.c_uint32),
        ("count_enum_blobs", ctypes.c_uint32),
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
GETENCODER = _iowr(0xA6, ctypes.sizeof(GetEncoder))
GETPROPERTY = _iowr(0xAA, ctypes.sizeof(GetProperty))
# DRM_IOCTL_MODE_PAGE_FLIP. A flip changes the buffer and leaves the
# mode alone. SETCRTC programs the mode again, and this panel draws its
# firmware logo for that retrain.
PAGE_FLIP = _iowr(0xB0, ctypes.sizeof(PageFlip))
PAGE_FLIP_EVENT = 1
FLIP_COMPLETE = 0x02
# DRM_IOCTL_WAIT_VBLANK. SETCRTC can return while the kernel still has
# that commit in flight, and the next compositor then refuses to paint.
_SYS_pidfd_getfd = 438
# Buffers this process created. A flip is only for someone else's frame.
OUR_FBS: set[int] = set()

CONNECTED = 1
# LVDS, eDP, DSI and DPI are the internal panel. VIRTUAL and WRITEBACK
# are not a picture the user is looking at.
INTERNAL_TYPES = {7, 14, 16, 17}
SKIP_TYPES = {15, 18}


def output_needs_cover(connector_type: int, scanning: bool) -> bool:
    """The panel connector's CRTC_ID, not a leftover controller, decides.

    After logout the old controller can still report a mode while the
    connector property Hyprland reads is 0. The panel paints its firmware
    logo into that gap.
    """
    if connector_type in SKIP_TYPES:
        return False
    return not scanning


def cover_rank(connector_type: int) -> int:
    return 0 if connector_type in INTERNAL_TYPES else 1


def _crtc_after_gap(plan: str, hold_fd: bool) -> int:
    """CRTC_ID the next client sees if the last fd closes before it opens.

    A splash frame we program is 7. Closing the last fd clears it.
    """
    del plan
    if not hold_fd:
        return 0
    return 7


def card_is_firmware_fb(driver: str) -> bool:
    """simpledrm is the firmware picture, still registered next to i915.

    Keeping that frame is what puts the mainboard logo on screen between
    the login screen and the desktop. It is not a second firmware boot,
    and the hidden boot menu is not involved.
    """
    return driver in {"simpledrm", "simple-framebuffer", "efifb"}


def handoff_plan(attached: int, scanning: bool) -> str:
    """Leave a controller that is already scanning out.

    Programming it again retrains the panel link, and this laptop draws
    its firmware logo for that retrain. A dark controller still needs one
    splash frame or the logo stays until the next compositor commits.
    """
    if attached and scanning:
        return "keep"
    return "paint"


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
    if crtc_id == 0:
        return False
    crtc = Crtc()
    crtc.crtc_id = crtc_id
    _ioctl(fd, GETCRTC, crtc)
    return crtc.mode_valid != 0 and crtc.fb_id != 0


def _encoder_link(fd: int, encoder_id: int) -> tuple[int, int]:
    if encoder_id == 0:
        return 0, 0
    enc = GetEncoder()
    enc.encoder_id = encoder_id
    _ioctl(fd, GETENCODER, enc)
    return int(enc.crtc_id), int(enc.possible_crtcs)


def _prop_name(fd: int, prop_id: int) -> str:
    prop = GetProperty()
    prop.prop_id = prop_id
    _ioctl(fd, GETPROPERTY, prop)
    return bytes(prop.name).split(b"\x00", 1)[0].decode("ascii", "replace")


def _attached_crtc(fd: int, info: GetConnector, prop_ids: ctypes.Array, prop_values: ctypes.Array) -> int | None:
    """The CRTC_ID property. None when the connector has no such property."""
    for index in range(int(info.count_props)):
        if _prop_name(fd, int(prop_ids[index])) != "CRTC_ID":
            continue
        return int(prop_values[index])
    return None


def _first_mode(fd: int, connector_id: int) -> tuple | None:
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
    mode_count = int(info.count_modes)
    prop_count = int(info.count_props)
    modes = (ModeInfo * mode_count)()
    prop_ids = (ctypes.c_uint32 * max(prop_count, 1))()
    prop_values = (ctypes.c_uint64 * max(prop_count, 1))()
    info.modes_ptr = ctypes.addressof(modes)
    info.count_modes = mode_count
    info.count_props = prop_count
    info.count_encoders = 0
    info.encoders_ptr = 0
    if prop_count:
        info.props_ptr = ctypes.addressof(prop_ids)
        info.prop_values_ptr = ctypes.addressof(prop_values)
    _ioctl(fd, GETCONNECTOR, info)
    if info.count_modes < 1:
        return None
    _encoder_crtc, possible = _encoder_link(fd, int(info.encoder_id))
    # Hyprland uses this property and ignores a controller the encoder
    # still names. Matching it is what tells a real scanout from a leftover.
    attached = _attached_crtc(fd, info, prop_ids, prop_values)
    if attached is None:
        attached = _encoder_crtc
    scanning = _crtc_scanning(fd, attached)
    return connector_id, int(info.connector_type), modes[0], scanning, possible, attached


def _cards() -> list[str]:
    dri = Path("/dev/dri")
    if not dri.is_dir():
        return []
    return sorted(str(p) for p in dri.glob("card[0-9]") if p.is_char_device())


def _driver_name(path: str) -> str:
    link = Path("/sys/class/drm") / Path(path).name / "device" / "driver"
    try:
        return link.resolve().name
    except OSError:
        return ""


def _make_splash_fb(fd: int, width: int, height: int) -> int:
    if width < 1 or height < 1:
        raise RuntimeError("mode has no size")
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
        # One write. A row loop on a Celeron leaves the firmware picture
        # up for the whole fill, which is the flash this frame exists to hide.
        pixel = splash_pixel()
        row = pixel * width
        if dumb.pitch > width * 4:
            row += b"\x00" * (dumb.pitch - width * 4)
        view.write(row * height)
    finally:
        view.close()
    fb = FbCmd(width=width, height=height, pitch=dumb.pitch, bpp=32, depth=24, handle=dumb.handle)
    _ioctl(fd, ADDFB, fb)
    fb_id = int(fb.fb_id)
    OUR_FBS.add(fb_id)
    return fb_id


def _crtc_fb(fd: int, crtc_id: int) -> int:
    crtc = Crtc()
    crtc.crtc_id = crtc_id
    _ioctl(fd, GETCRTC, crtc)
    return int(crtc.fb_id)


def _wait_flip(fd: int) -> bool:
    """True once the kernel reports the flip. Hyprland must not start
    while that flip is still queued."""
    deadline = time.monotonic() + 0.25
    pending = b""
    while time.monotonic() < deadline:
        remain = max(0.0, deadline - time.monotonic())
        ready, _, _ = select.select([fd], [], [], remain)
        if not ready:
            return False
        try:
            chunk = os.read(fd, 256)
        except OSError:
            return False
        if not chunk:
            return False
        pending += chunk
        while len(pending) >= 8:
            length = int.from_bytes(pending[4:8], "little")
            if length < 8 or len(pending) < length:
                break
            event, pending = pending[:length], pending[length:]
            if int.from_bytes(event[0:4], "little") == FLIP_COMPLETE:
                return True
    return False


def _replace_live(fd: int, crtc_id: int) -> bool:
    """Swap our buffer onto a controller that is already scanning.

    SETCRTC would program the mode again. This panel draws the firmware
    logo for that retrain, including when the mode did not change.
    """
    info = Crtc()
    info.crtc_id = crtc_id
    _ioctl(fd, GETCRTC, info)
    if info.mode_valid == 0:
        return False
    current = int(info.fb_id)
    if current in OUR_FBS:
        return True
    fb_id = _make_splash_fb(fd, int(info.mode.hdisplay), int(info.mode.vdisplay))
    flip = PageFlip(crtc_id=crtc_id, fb_id=fb_id, flags=PAGE_FLIP_EVENT, reserved=0, user_data=1)
    try:
        _ioctl(fd, PAGE_FLIP, flip)
    except OSError as exc:
        print(f"seat-cover: page flip failed ({exc})", file=sys.stderr)
        return False
    if not _wait_flip(fd):
        print("seat-cover: page flip did not finish", file=sys.stderr)
    return True


def paint(fd: int, crtc_id: int, connector_id: int, mode: ModeInfo) -> int:
    """Program one frame and return the fd that keeps the buffer alive.

    Only for a controller that is off. A scanning one is page-flipped.
    """
    fb_id = _make_splash_fb(fd, int(mode.hdisplay), int(mode.vdisplay))
    _ioctl(fd, SET_MASTER)
    conn = ctypes.c_uint32(connector_id)
    crtc = Crtc()
    crtc.set_connectors_ptr = ctypes.addressof(conn)
    crtc.count_connectors = 1
    crtc.crtc_id = crtc_id
    crtc.fb_id = fb_id
    crtc.mode_valid = 1
    crtc.mode = mode
    _ioctl(fd, SETCRTC, crtc)
    # The legacy modeset can return before the kernel has finished the
    # commit. Dropping master then leaves a page-flip in flight and the
    # next compositor logs that it cannot commit.
    blank = VBlank(type=1, sequence=1)
    try:
        _ioctl(fd, WAIT_VBLANK, blank)
    except OSError:
        pass
    _ioctl(fd, DROP_MASTER)
    print(f"seat-cover: painted {mode.hdisplay}x{mode.vdisplay} and dropped master", file=sys.stderr)
    return fd


def _hypr_visible() -> bool:
    roots: list[Path] = []
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if runtime:
        roots.append(Path(runtime) / "hypr")
    # The boot pin runs as root, before the login screen has a runtime dir.
    run_user = Path("/run/user")
    if run_user.is_dir():
        roots.extend(run_user.glob("*/hypr"))
    for root in roots:
        try:
            if root.is_dir() and any(root.iterdir()):
                return True
        except OSError:
            continue
    return False


def _wait_for_compositor() -> None:
    start = time.monotonic()
    seen: float | None = None
    while time.monotonic() - start < HOLD_SECONDS:
        if seen is None and _hypr_visible():
            seen = time.monotonic()
        if seen is not None and time.monotonic() - seen >= AFTER_SOCKET:
            return
        time.sleep(0.1)


def _hyprland_running() -> bool:
    proc = Path("/proc")
    try:
        entries = list(proc.iterdir())
    except OSError:
        return False
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(encoding="ascii", errors="replace").strip()
        except OSError:
            continue
        if comm in {"Hyprland", "hyprland"}:
            return True
    return False


def _wait_previous_compositor() -> bool:
    """True once the previous Hyprland has exited.

    The login compositor turns the panel off as it leaves. Painting before
    that exit is overwritten, and the panel shows its firmware picture.
    """
    deadline = time.monotonic() + 2
    while _hyprland_running():
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.05)
    return True


def _paint_best(fd: int) -> int:
    """Program the preferred connector. The attached CRTC_ID, -1 if busy, else 0."""
    crtcs, conns = _resources(fd)
    outputs: list[tuple[int, int, ModeInfo, int]] = []
    for conn in conns:
        found = _first_mode(fd, conn)
        if found is None:
            continue
        connector_id, kind, mode, _scanning, possible, _attached = found
        if kind in SKIP_TYPES:
            continue
        outputs.append((cover_rank(kind), connector_id, mode, possible))
    if not outputs:
        return 0
    _rank, connector_id, mode, possible = min(outputs, key=lambda item: item[0])
    for crtc in _ordered_crtcs(crtcs, possible):
        try:
            paint(fd, crtc, connector_id, mode)
        except OSError as exc:
            _drop_master(fd)
            if exc.errno == errno.EBUSY:
                return -1
            print(f"seat-cover: paint failed ({exc})", file=sys.stderr)
            continue
        found = _first_mode(fd, connector_id)
        attached = int(found[5]) if found is not None else 0
        if attached:
            print(f"seat-cover: frame held CRTC_ID={attached}", file=sys.stderr)
            return attached
        print(f"seat-cover: paint did not attach connector {connector_id}", file=sys.stderr)
        _drop_master(fd)
    return 0


def _live_crtc(fd: int) -> int:
    """CRTC_ID of a connector that is already scanning, internal panel first."""
    _crtcs, conns = _resources(fd)
    best: tuple[int, int] | None = None
    for conn in conns:
        found = _first_mode(fd, conn)
        if found is None:
            continue
        _cid, kind, _mode, scanning, _possible, attached = found
        if kind in SKIP_TYPES or handoff_plan(attached, scanning) != "keep":
            continue
        rank = cover_rank(kind)
        if best is None or rank < best[0]:
            best = (rank, attached)
    return 0 if best is None else best[1]


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


def _acquire_master(fd: int) -> bool:
    # The client that is exiting still owns the device for a moment.
    # EBUSY is that wait. Anything else means we must not block login.
    deadline = time.monotonic() + 2
    while True:
        try:
            _ioctl(fd, SET_MASTER)
            return True
        except OSError as exc:
            if exc.errno != errno.EBUSY or time.monotonic() >= deadline:
                return False
            time.sleep(0.05)


def _drop_master(fd: int) -> None:
    try:
        _ioctl(fd, DROP_MASTER)
    except OSError:
        pass


def _comm_running(name: str) -> bool:
    root = Path("/proc")
    try:
        entries = list(root.iterdir())
    except OSError:
        return False
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(encoding="ascii", errors="replace").strip()
        except OSError:
            continue
        if comm == name:
            return True
    return False


def _plymouth_release_master() -> bool:
    """Drop Plymouth's DRM master without letting its renderer run.

    `plymouth deactivate` turns the CRTC off. The panel is dark until
    something programs the mode again, and that retrain is the gap
    between the splash and the login screen.
    """
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long
    libc.syscall.argtypes = [ctypes.c_long, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    released = False
    try:
        entries = list(Path("/proc").iterdir())
    except OSError:
        return False
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(encoding="ascii", errors="replace").strip()
        except OSError:
            continue
        if comm != "plymouthd":
            continue
        try:
            pidfd = os.pidfd_open(int(entry.name))
        except (AttributeError, OSError):
            continue
        try:
            for fdent in (entry / "fd").iterdir():
                if not fdent.name.isdigit():
                    continue
                try:
                    target = os.readlink(fdent)
                except OSError:
                    continue
                if not target.startswith("/dev/dri/card"):
                    continue
                dup = libc.syscall(_SYS_pidfd_getfd, pidfd, int(fdent.name), 0)
                if dup < 0:
                    continue
                try:
                    _ioctl(int(dup), DROP_MASTER)
                    released = True
                    print("seat-cover: plymouth released the display without turning it off", file=sys.stderr)
                except OSError as exc:
                    print(f"seat-cover: plymouth master drop failed ({exc})", file=sys.stderr)
                finally:
                    os.close(int(dup))
        finally:
            os.close(pidfd)
    return released


def _plymouth_drop_master() -> None:
    """Plymouth keeps DRM master until it exits, and exiting destroys the
    buffer that is on screen. Deactivate drops master and leaves that
    buffer, so a page flip can take the picture over before the exit.
    """
    try:
        ping = subprocess.run(
            ["plymouth", "--ping"],
            timeout=1,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return
    if ping.returncode != 0:
        return
    try:
        subprocess.run(
            ["plymouth", "deactivate"],
            timeout=1,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def _adopt_fd(fd: int, modeset: bool = True, hold_master: bool = False) -> str:
    """Caller holds master. A scanning picture is page-flipped. An off
    controller is programmed once, and only when modeset is allowed.
    Logout and login must not modeset: this panel draws its firmware
    logo for every retrain, and the next compositor retrains again.
    hold_master leaves this process master so Plymouth's quit cannot
    turn the panel off after the flip."""
    global HELD_MASTER
    live = _live_crtc(fd)
    if live:
        if _crtc_fb(fd, live) in OUR_FBS:
            if hold_master:
                HELD_MASTER = True
            else:
                _drop_master(fd)
            return f"seat-cover: keeping live scanout CRTC_ID={live}"
        if _replace_live(fd, live) and _crtc_fb(fd, live) in OUR_FBS:
            if hold_master:
                HELD_MASTER = True
            else:
                _drop_master(fd)
            return f"seat-cover: replaced scanout without a modeset CRTC_ID={live}"
        # The flip did not land. An empty note makes the first adopt
        # try again. SETCRTC here would be the logo.
        _drop_master(fd)
        return ""
    if not modeset:
        _drop_master(fd)
        return ""
    held = _paint_best(fd)
    if held > 0:
        return f"seat-cover: frame held CRTC_ID={held}"
    if held == 0:
        _drop_master(fd)
        return "seat-cover: guard found no mode"
    return ""


def _ordered_crtcs(crtcs: list[int], possible: int) -> list[int]:
    if possible == 0:
        return crtcs
    first = [crtc for index, crtc in enumerate(crtcs) if possible & (1 << index)]
    rest = [crtc for crtc in crtcs if crtc not in first]
    return first + rest


def hold() -> int:
    if os.environ.get("MODERN_SEAT_COVER") == "0":
        return 0
    opened: list[tuple[str, int]] = []
    # rank, path, fd, crtcs, connector id, mode, possible crtcs
    outputs: list[tuple[int, str, int, list[int], int, ModeInfo, int]] = []
    try:
        for path in _cards():
            fd: int | None = None
            try:
                driver = _driver_name(path)
                if card_is_firmware_fb(driver):
                    print(f"seat-cover: skipping firmware framebuffer {path} ({driver})", file=sys.stderr)
                    continue
                fd = os.open(path, os.O_RDWR | os.O_CLOEXEC)
                crtcs, conns = _resources(fd)
                opened.append((path, fd))
                for conn in conns:
                    found = _first_mode(fd, conn)
                    if found is None:
                        continue
                    connector_id, kind, mode, _scanning, possible, _attached = found
                    if kind in SKIP_TYPES:
                        continue
                    outputs.append((cover_rank(kind), path, fd, crtcs, connector_id, mode, possible))
            except Exception as exc:
                print(f"seat-cover: skipped {path} ({exc})", file=sys.stderr)
                if fd is not None and all(other != fd for _, other in opened):
                    try:
                        os.close(fd)
                    except OSError:
                        pass
        if not outputs:
            print("seat-cover: no display to cover", file=sys.stderr)
            return 0
        _rank, path, fd, crtcs, connector_id, mode, possible = min(outputs, key=lambda item: item[0])
        for _other_path, other in opened:
            if other != fd:
                os.close(other)
        opened = [(path, fd)]
        # The login compositor disables the panel as it exits. A frame
        # programmed before that exit is gone by the time Hyprland looks,
        # and the panel draws its firmware picture. Two seconds is the
        # cap so a stuck login screen cannot block the desktop.
        if not _wait_previous_compositor():
            print("seat-cover: previous compositor still exiting", file=sys.stderr)
        # Become master only long enough to program the frame, then drop
        # it. Hyprland must be able to open the device. The fd stays open
        # so i915 does not run lastclose and restore the firmware picture.
        if not _acquire_master(fd):
            print("seat-cover: previous display owner still active", file=sys.stderr)
            _hold_fd(fd)
            opened.clear()
            return 0
        live = _live_crtc(fd)
        if live:
            # The guard, or the client that just exited, already has a
            # frame on the link. Another modeset is the logo flash.
            if _crtc_fb(fd, live) not in OUR_FBS:
                _replace_live(fd, live)
            print(f"seat-cover: keeping live scanout CRTC_ID={live}", file=sys.stderr)
            _drop_master(fd)
            _hold_fd(fd)
            opened.clear()
            return 0
        # The previous compositor already cleared CRTC_ID. Programming a
        # mode here retrains the panel, which is the firmware logo, and
        # the next compositor retrains it again. Leave the link alone.
        _drop_master(fd)
        print("seat-cover: link already dark, leaving the mode for the next compositor", file=sys.stderr)
        _hold_fd(fd)
        opened.clear()
        return 0
    finally:
        for _path, fd in opened:
            try:
                os.close(fd)
            except OSError:
                pass


def _first_adopt(fds: list[int]) -> str:
    """Take the picture over before Plymouth's process exits.

    After that exit the scanning buffer is gone and the panel is dark.
    Putting a frame on a dark controller retrains the link, and the
    firmware logo is what this panel draws during the retrain.
    """
    # deactivate turns the CRTC off, so it is only the fallback when
    # Plymouth's own fd could not be told to drop master.
    stole = _plymouth_release_master()
    if not stole:
        _plymouth_drop_master()
    deadline = time.monotonic() + ADOPT_SECONDS
    note = ""
    while time.monotonic() < deadline and not note:
        for fd in fds:
            try:
                _ioctl(fd, SET_MASTER)
            except OSError:
                continue
            note = _adopt_fd(fd, hold_master=stole)
            # "no mode" can be a connector that is not ready yet. A
            # landed flip or a programmed frame is done.
            if note and not note.endswith("no mode"):
                return note
        time.sleep(0.02)
    return note


def _signal_ready(write_fd: int) -> None:
    try:
        os.write(write_fd, b"\n")
    except OSError:
        pass
    try:
        os.close(write_fd)
    except OSError:
        pass


def pin() -> int:
    """Hold the real GPU from before Plymouth exits until the machine stops.

    The parent waits only until the first frame is in place, then Plymouth
    is allowed to quit. The child is not master while a compositor is
    scanning, and it drops master after every frame.
    """
    if os.environ.get("MODERN_SEAT_COVER") == "0":
        return 0
    if _hyprland_running():
        print("seat-cover: pin skipped, a compositor already owns the display", file=sys.stderr)
        return 0
    opened: list[int] = []
    for path in _cards():
        driver = _driver_name(path)
        if card_is_firmware_fb(driver):
            print(f"seat-cover: skipping firmware framebuffer {path} ({driver})", file=sys.stderr)
            continue
        try:
            opened.append(os.open(path, os.O_RDWR | os.O_CLOEXEC))
        except OSError as exc:
            print(f"seat-cover: pin skipped {path} ({exc})", file=sys.stderr)
    if not opened:
        print("seat-cover: no display to pin", file=sys.stderr)
        return 0
    read_fd, write_fd = os.pipe()
    pid = os.fork()
    if pid > 0:
        os.close(write_fd)
        for fd in opened:
            os.close(fd)
        # Plymouth quit is ordered after this process. Waiting here is
        # what keeps Plymouth alive until its frame has been replaced.
        # The cap is so a stuck device cannot hold the splash up.
        select.select([read_fd], [], [], ADOPT_SECONDS + 0.5)
        os.close(read_fd)
        return 0
    os.close(read_fd)
    os.setsid()
    try:
        note = _first_adopt(opened)
        if note:
            print(note, file=sys.stderr)
        _signal_ready(write_fd)
        if HELD_MASTER:
            # Plymouth quit is running now. It cannot disable the CRTC
            # while this process is still master, and it does not wait
            # forever for a master it will not get. Drop once it is gone
            # so the login compositor can open the device.
            deadline = time.monotonic() + 3
            while _comm_running("plymouthd") and time.monotonic() < deadline:
                time.sleep(0.02)
            for fd in opened:
                _drop_master(fd)
        # Stay up for logout as well. The previous compositor turns the
        # panel off as it leaves. Reprogramming that dark link retrains
        # it, which is the firmware logo, and the next compositor does
        # it again. A picture that is still scanning is page-flipped.
        # A dark one is left for that next compositor.
        reported = note
        quiet_until = 0.0
        while True:
            if time.monotonic() < quiet_until:
                time.sleep(0.05)
                continue
            # A scanning picture stays untouched. Taking master to look
            # again races the compositor that is about to open the device.
            scanning = False
            for fd in opened:
                try:
                    if _live_crtc(fd):
                        scanning = True
                        break
                except OSError:
                    continue
            if scanning:
                time.sleep(0.2 if _hyprland_running() else 0.05)
                continue
            delay = 0.05
            new_note = ""
            for fd in opened:
                try:
                    _ioctl(fd, SET_MASTER)
                except OSError:
                    delay = 0.02
                    continue
                new_note = _adopt_fd(fd, modeset=False)
                break
            if new_note and new_note != reported:
                print(new_note, file=sys.stderr)
                reported = new_note
            # A dark controller was just programmed. Doing it again on
            # the next tick retrains the link, which is the logo.
            if new_note.startswith("seat-cover: frame held"):
                quiet_until = time.monotonic() + 1.0
            time.sleep(delay)
    finally:
        for fd in opened:
            try:
                os.close(fd)
            except OSError:
                pass
        os._exit(0)


def self_test() -> int:
    if ctypes.sizeof(ModeInfo) != 68 or ctypes.sizeof(Crtc) != 104:
        print("seat-cover: mode struct size drifted", file=sys.stderr)
        return 1
    if ctypes.sizeof(GetConnector) != 80 or ctypes.sizeof(CardRes) != 64:
        print("seat-cover: connector struct size drifted", file=sys.stderr)
        return 1
    if ctypes.sizeof(CreateDumb) != 32 or ctypes.sizeof(MapDumb) != 16 or ctypes.sizeof(FbCmd) != 28:
        print("seat-cover: buffer struct size drifted", file=sys.stderr)
        return 1
    if ctypes.sizeof(GetProperty) != 64 or ctypes.sizeof(GetEncoder) != 20:
        print("seat-cover: encoder struct size drifted", file=sys.stderr)
        return 1
    if ctypes.sizeof(PageFlip) != 24 or ctypes.sizeof(DrmEventVblank) != 32 or ctypes.sizeof(VBlank) != 24:
        print("seat-cover: page-flip struct size drifted", file=sys.stderr)
        return 1
    if not output_needs_cover(14, False) or output_needs_cover(14, True) or output_needs_cover(15, False):
        print("seat-cover: cover decision is wrong", file=sys.stderr)
        return 1
    if cover_rank(14) >= cover_rank(11):
        print("seat-cover: internal panel is not chosen first", file=sys.stderr)
        return 1
    if splash_pixel() != bytes((0x14, 0x12, 0x18, 0x00)):
        print("seat-cover: splash pixel is not #141218", file=sys.stderr)
        return 1
    # A scanning controller is left alone. Reprogramming it retrains the
    # panel and the firmware logo shows for that retrain. A dark one is painted.
    if handoff_plan(112, True) != "keep" or handoff_plan(0, False) != "paint":
        print("seat-cover: handoff plan is wrong", file=sys.stderr)
        return 1
    if not card_is_firmware_fb("simpledrm") or card_is_firmware_fb("i915"):
        print("seat-cover: firmware framebuffer detection is wrong", file=sys.stderr)
        return 1
    if _crtc_after_gap("paint", hold_fd=False) != 0 or _crtc_after_gap("paint", hold_fd=True) == 0:
        print("seat-cover: lastclose model is wrong", file=sys.stderr)
        return 1
    if _crtc_after_gap("paint", hold_fd=True) == 0:
        print("seat-cover: a painted frame must survive until the next client", file=sys.stderr)
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
            crtcs, conns = _resources(fd)
            for crtc in crtcs:
                _crtc_scanning(fd, crtc)
            for conn in conns:
                _first_mode(fd, conn)
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


def dry_run() -> int:
    """Read the connectors only. Does not take the display or change a mode."""
    any_card = False
    for path in _cards():
        driver = _driver_name(path)
        if card_is_firmware_fb(driver):
            print(f"seat-cover: skipping firmware framebuffer {path} ({driver})", file=sys.stderr)
            continue
        try:
            fd = os.open(path, os.O_RDWR | os.O_CLOEXEC)
        except OSError as exc:
            print(f"seat-cover: {path} not opened ({exc})", file=sys.stderr)
            continue
        any_card = True
        try:
            _crtcs, conns = _resources(fd)
            for conn in conns:
                found = _first_mode(fd, conn)
                if found is None:
                    continue
                connector_id, kind, mode, scanning, _possible, attached = found
                if kind in SKIP_TYPES:
                    continue
                plan = handoff_plan(attached, scanning)
                print(
                    f"seat-cover: {path} connector {connector_id} type {kind} "
                    f"{mode.hdisplay}x{mode.vdisplay} CRTC_ID={attached} "
                    f"scanning={scanning} plan={plan}",
                    file=sys.stderr,
                )
        finally:
            os.close(fd)
    if not any_card:
        print("seat-cover: no card to read", file=sys.stderr)
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "hold"
    if cmd == "--self-test":
        return self_test()
    if cmd == "--dry-run":
        return dry_run()
    if cmd == "hold":
        return hold()
    if cmd == "pin":
        return pin()
    print(f"seat-cover: unknown command {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
