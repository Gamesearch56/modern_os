#!/usr/bin/env bash
# A login keyring that does not open with the typed password must be
# replaced, and the default name must stay "login".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-keyring-login: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-keyring-login: ok %s\n' "$*"; }

MATCH="$ROOT/install/system/greetd/keyring-match.py"
LOGIN="$ROOT/install/system/greetd/keyring-login.sh"

work="$(mktemp -d "${TMPDIR:-/tmp}/modern-keyring-XXXXXX")"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# Same on-disk layout gnome-keyring 51 writes for an empty login collection.
/usr/bin/python3 - "$work/login.keyring" <<'PY'
import ctypes
import hashlib
import sys

def u32(n):
    return int(n).to_bytes(4, "big")

def string(text):
    raw = text.encode()
    return u32(len(raw)) + raw

password = b"s3cret-login"
salt = b"01234567"
iterations = 1000
digest = hashlib.sha256(password + salt).digest()
for _ in range(iterations - 1):
    digest = hashlib.sha256(digest).digest()
key, iv = digest[:16], digest[16:32]
body = b""
plain = hashlib.md5(body).digest() + body

lib = ctypes.CDLL("libcrypto.so.3")
void = ctypes.c_void_p
lib.EVP_CIPHER_CTX_new.restype = void
lib.EVP_aes_128_cbc.restype = void
lib.EVP_EncryptInit_ex.argtypes = [void, void, void, ctypes.c_char_p, ctypes.c_char_p]
lib.EVP_EncryptInit_ex.restype = ctypes.c_int
lib.EVP_CIPHER_CTX_set_padding.argtypes = [void, ctypes.c_int]
lib.EVP_EncryptUpdate.argtypes = [
    void, ctypes.c_char_p, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p, ctypes.c_int,
]
lib.EVP_EncryptUpdate.restype = ctypes.c_int
lib.EVP_CIPHER_CTX_free.argtypes = [void]
ctx = lib.EVP_CIPHER_CTX_new()
lib.EVP_EncryptInit_ex(ctx, lib.EVP_aes_128_cbc(), None, key, iv)
lib.EVP_CIPHER_CTX_set_padding(ctx, 0)
out = ctypes.create_string_buffer(len(plain))
wrote = ctypes.c_int(0)
lib.EVP_EncryptUpdate(ctx, out, ctypes.byref(wrote), plain, len(plain))
lib.EVP_CIPHER_CTX_free(ctx)
blob = out.raw[: wrote.value]

data = b"GnomeKeyring\n\r\0\n"
data += bytes((0, 0, 0, 0))
data += string("Login")
data += u32(0) + u32(0) + u32(0) + u32(0)
data += u32(0) + u32(0) + u32(iterations) + salt
data += u32(0) * 4
data += u32(0)
data += u32(len(blob)) + blob
with open(sys.argv[1], "wb") as handle:
    handle.write(data)
PY

key="$work/login.keyring"
if printf '%s' 's3cret-login' | /usr/bin/python3 "$MATCH" "$key"; then
    if printf '%s' 'wrong-password' | /usr/bin/python3 "$MATCH" "$key"; then
        err "a wrong password was accepted"
    else
        ok "login keyring opens only with the password that created it"
    fi
else
    err "the password that created the keyring was rejected"
fi

fresh="$work/fresh"
mkdir -p "$fresh/.local/share/keyrings"
cp -a "$key" "$fresh/.local/share/keyrings/login.keyring"
printf 'wrong-password\n' | MODERN_KEYRING_HOME="$fresh" "$LOGIN"
if [ ! -f "$fresh/.local/share/keyrings/login.keyring" ] \
    && [ "$(cat "$fresh/.local/share/keyrings/default")" = "login" ]; then
    ok "a mismatched login keyring is removed and login stays the default"
else
    err "mismatched login keyring should be removed"
fi

cp -a "$key" "$fresh/.local/share/keyrings/login.keyring"
printf 's3cret-login\n' | MODERN_KEYRING_HOME="$fresh" "$LOGIN"
if [ -f "$fresh/.local/share/keyrings/login.keyring" ] \
    && [ "$(cat "$fresh/.local/share/keyrings/default")" = "login" ]; then
    ok "a matching login keyring is kept"
else
    err "a matching keyring must be kept"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-keyring-login: ok\n'
