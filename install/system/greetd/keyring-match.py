#!/usr/bin/env python3
# Exit 0 when login.keyring opens with the password on stdin, or the file
# is not the gnome-keyring format this checker understands (caller keeps it).
# Exit 1 when it is that format and the password does not match.
# Decrypted bytes are only compared to their MD5 and then dropped.

import ctypes
import hashlib
import sys

HEADER = b"GnomeKeyring\n\r\0\n"
MAX_ITERS = 20000
MAX_ITEMS = 100000


def _u32(data, off):
    if off + 4 > len(data):
        raise ValueError("truncated")
    return int.from_bytes(data[off : off + 4], "big"), off + 4


def _skip_string(data, off):
    length, off = _u32(data, off)
    if length == 0xFFFFFFFF:
        return off
    if length > len(data) - off:
        raise ValueError("truncated")
    return off + length


def _skip_attributes(data, off):
    count, off = _u32(data, off)
    if count > MAX_ITEMS:
        raise ValueError("attributes")
    for _ in range(count):
        off = _skip_string(data, off)
        kind, off = _u32(data, off)
        if kind == 0:
            off = _skip_string(data, off)
        elif kind == 1:
            _, off = _u32(data, off)
        else:
            raise ValueError("attribute")
    return off


def _ciphertext(data):
    if not data.startswith(HEADER) or len(data) < 20:
        return None
    off = len(HEADER)
    if data[off : off + 4] != bytes((0, 0, 0, 0)):
        return None
    off += 4
    off = _skip_string(data, off)
    for _ in range(4):
        _, off = _u32(data, off)
    _, off = _u32(data, off)
    _, off = _u32(data, off)
    iterations, off = _u32(data, off)
    if iterations < 1 or iterations > MAX_ITERS or off + 8 > len(data):
        return None
    salt = data[off : off + 8]
    off += 8
    for _ in range(4):
        _, off = _u32(data, off)
    items, off = _u32(data, off)
    if items > MAX_ITEMS:
        return None
    for _ in range(items):
        _, off = _u32(data, off)
        _, off = _u32(data, off)
        off = _skip_attributes(data, off)
    size, off = _u32(data, off)
    if size == 0 or size % 16 != 0 or off + size > len(data):
        return None
    return iterations, salt, data[off : off + size]


def _derive(password, salt, iterations):
    digest = hashlib.sha256(password + salt).digest()
    for _ in range(iterations - 1):
        digest = hashlib.sha256(digest).digest()
    return digest[:16], digest[16:32]


def _aes_cbc_decrypt(key, iv, blob):
    lib = ctypes.CDLL("libcrypto.so.3")
    void = ctypes.c_void_p
    lib.EVP_CIPHER_CTX_new.restype = void
    lib.EVP_aes_128_cbc.restype = void
    lib.EVP_DecryptInit_ex.argtypes = [void, void, void, ctypes.c_char_p, ctypes.c_char_p]
    lib.EVP_DecryptInit_ex.restype = ctypes.c_int
    lib.EVP_CIPHER_CTX_set_padding.argtypes = [void, ctypes.c_int]
    lib.EVP_DecryptUpdate.argtypes = [
        void,
        ctypes.c_char_p,
        ctypes.POINTER(ctypes.c_int),
        ctypes.c_char_p,
        ctypes.c_int,
    ]
    lib.EVP_DecryptUpdate.restype = ctypes.c_int
    lib.EVP_CIPHER_CTX_free.argtypes = [void]
    ctx = lib.EVP_CIPHER_CTX_new()
    if not ctx:
        raise OSError("cipher")
    try:
        if lib.EVP_DecryptInit_ex(ctx, lib.EVP_aes_128_cbc(), None, key, iv) != 1:
            raise OSError("cipher")
        lib.EVP_CIPHER_CTX_set_padding(ctx, 0)
        out = ctypes.create_string_buffer(len(blob))
        wrote = ctypes.c_int(0)
        if lib.EVP_DecryptUpdate(ctx, out, ctypes.byref(wrote), blob, len(blob)) != 1:
            raise OSError("cipher")
        return out.raw[: wrote.value]
    finally:
        lib.EVP_CIPHER_CTX_free(ctx)


def password_matches(path, password):
    with open(path, "rb") as handle:
        data = handle.read(8 * 1024 * 1024)
    parsed = _ciphertext(data)
    if parsed is None:
        return None
    iterations, salt, blob = parsed
    key, iv = _derive(password, salt, iterations)
    plain = _aes_cbc_decrypt(key, iv, blob)
    if len(plain) < 16:
        return False
    expect = hashlib.md5(plain[16:]).digest()
    return expect == plain[:16]


def main(argv):
    if len(argv) != 2:
        return 0
    password = sys.stdin.buffer.read()
    if password.endswith(b"\n"):
        password = password[:-1]
    try:
        matched = password_matches(argv[1], password)
    except (OSError, ValueError):
        return 0
    if matched is None or matched:
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
