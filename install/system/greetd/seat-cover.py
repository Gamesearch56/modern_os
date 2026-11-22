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
    """Always replace the scanout. A live CRTC can still be the firmware frame."""
    del attached, scanning
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
        # Become master only long enough to see the connector after the
        # previous client has let go, then drop it. Hyprland must be able
        # to open the device. The fd stays open so i915 does not run
        # lastclose and blank the panel in between.
        if not _acquire_master(fd):
            print("seat-cover: previous display owner still active", file=sys.stderr)
            _hold_fd(fd)
            opened.clear()
            return 0
        found = _first_mode(fd, connector_id)
        plan = "paint"
        attached = 0
        if found is not None:
            _cid, _kind, mode, scanning, possible, attached = found
            plan = handoff_plan(attached, scanning)
        if plan == "paint" and found is not None:
            painted = False
            last_exc: OSError | None = None
            for crtc in _ordered_crtcs(crtcs, possible):
                try:
                    paint(fd, crtc, connector_id, mode)
                    painted = True
                    break
                except OSError as exc:
                    last_exc = exc
                    _drop_master(fd)
            if not painted:
                print(f"seat-cover: paint failed ({last_exc})", file=sys.stderr)
                _drop_master(fd)
        else:
            _drop_master(fd)
            print(f"seat-cover: no mode to replace CRTC_ID={attached}", file=sys.stderr)
        _hold_fd(fd)
        opened.clear()
        return 0
    finally:
        for _path, fd in opened:
            try:
                os.close(fd)
            except OSError:
                pass


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
    if not output_needs_cover(14, False) or output_needs_cover(14, True) or output_needs_cover(15, False):
        print("seat-cover: cover decision is wrong", file=sys.stderr)
        return 1
    if cover_rank(14) >= cover_rank(11):
        print("seat-cover: internal panel is not chosen first", file=sys.stderr)
        return 1
    if splash_pixel() != bytes((0x14, 0x12, 0x18, 0x00)):
        print("seat-cover: splash pixel is not #141218", file=sys.stderr)
        return 1
    # Issue 24: CRTC 112 was still named, the cover closed the device,
    # and the next client observed no CRTC. Holding the fd keeps the id.
    if handoff_plan(112, True) != "paint" or handoff_plan(0, False) != "paint":
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
    print(f"seat-cover: unknown command {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
