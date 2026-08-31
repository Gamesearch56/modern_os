#!/usr/bin/env python3
"""Local HTTP/CONNECT proxy that drops denylisted hosts. No TLS MITM."""
from __future__ import annotations

import argparse
import select
import socket
import sys
import threading
from pathlib import Path

LISTEN = "127.0.0.1"
BUF = 65536
CONNECT_TIMEOUT = 15


def load_hosts(path: Path) -> set[str]:
    out: set[str] = set()
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        host = line.split()[-1].lower().rstrip(".")
        if host and host not in ("localhost", "broadcasthost"):
            out.add(host)
    return out


def is_blocked(host: str, denylist: set[str]) -> bool:
    host = host.lower().rstrip(".")
    if not host:
        return False
    labels = host.split(".")
    for i in range(len(labels)):
        if ".".join(labels[i:]) in denylist:
            return True
    return False


def read_headers(conn: socket.socket) -> bytes:
    data = b""
    conn.settimeout(CONNECT_TIMEOUT)
    while b"\r\n\r\n" not in data and len(data) < 65536:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def parse_target(header: bytes) -> tuple[str, str, int] | None:
    try:
        first = header.split(b"\r\n", 1)[0].decode("ascii", "replace")
    except (IndexError, UnicodeError):
        return None
    parts = first.split()
    if len(parts) < 2:
        return None
    method, target = parts[0].upper(), parts[1]
    if method == "CONNECT":
        hostport = target
        default_port = 443
    else:
        if target.startswith("http://"):
            rest = target[7:]
            hostport = rest.split("/", 1)[0]
        else:
            hostport = ""
            for line in header.split(b"\r\n"):
                if line.lower().startswith(b"host:"):
                    hostport = line.split(b":", 1)[1].strip().decode("ascii", "replace")
                    break
        default_port = 80
    if not hostport:
        return None
    if hostport.startswith("[") and "]" in hostport:
        host = hostport[1 : hostport.index("]")]
        rest = hostport[hostport.index("]") + 1 :]
        port = int(rest[1:]) if rest.startswith(":") else default_port
    elif hostport.count(":") == 1:
        host, port_s = hostport.split(":")
        port = int(port_s)
    else:
        host, port = hostport, default_port
    return method, host, port


def splice(a: socket.socket, b: socket.socket) -> None:
    sockets = [a, b]
    try:
        while True:
            readable, _, _ = select.select(sockets, [], [], 60)
            if not readable:
                return
            for src in readable:
                dst = b if src is a else a
                data = src.recv(BUF)
                if not data:
                    return
                dst.sendall(data)
    except OSError:
        return


def deny(conn: socket.socket) -> None:
    try:
        conn.sendall(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
    except OSError:
        pass


def handle(conn: socket.socket, denylist: set[str]) -> None:
    remote = None
    try:
        header = read_headers(conn)
        parsed = parse_target(header)
        if parsed is None:
            deny(conn)
            return
        method, host, port = parsed
        if is_blocked(host, denylist):
            deny(conn)
            return
        remote = socket.create_connection((host, port), CONNECT_TIMEOUT)
        if method == "CONNECT":
            conn.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        else:
            remote.sendall(header)
        conn.settimeout(None)
        remote.settimeout(None)
        splice(conn, remote)
    except OSError:
        deny(conn)
    finally:
        if remote is not None:
            try:
                remote.close()
            except OSError:
                pass
        try:
            conn.close()
        except OSError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hosts", required=True, type=Path)
    args = parser.parse_args()
    denylist = load_hosts(args.hosts)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((LISTEN, 0))
    sock.listen(64)
    port = sock.getsockname()[1]
    print(f"PORT {port}", flush=True)
    while True:
        conn, _ = sock.accept()
        threading.Thread(target=handle, args=(conn, denylist), daemon=True).start()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
