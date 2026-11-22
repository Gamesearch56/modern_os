#!/usr/bin/env bash
# Deploy key: which file is trusted, which GitHub URL it unlocks, and
# that desktop-sync passes only that key to ssh. No network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib/deploy-key.sh
source "$ROOT/scripts/lib/deploy-key.sh"
SYNC="$ROOT/scripts/desktop-sync.sh"
FAIL=0
err() { printf 'test-deploy-key: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-deploy-key: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-dkey-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

new_key() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    ssh-keygen -t ed25519 -N "" -C test -f "$path" >/dev/null
    chmod 0600 "$path"
}

if git -C "$ROOT" check-ignore -q secrets/github-deploy-key \
    && git -C "$ROOT" check-ignore -q secrets/github-deploy-key.pub; then
    ok "private deploy key is gitignored"
else
    err "secrets/github-deploy-key must stay gitignored"
fi

python3 - "$ROOT/scripts/lib/github-known-hosts" <<'PY'
import base64, hashlib, sys
expected = {
    "ssh-ed25519": "SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU",
    "ecdsa-sha2-nistp256": "SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM",
    "ssh-rsa": "SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s",
}
seen = {}
for raw in open(sys.argv[1]):
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    host, kind, blob = line.split()
    if host != "github.com":
        raise SystemExit(f"unexpected host {host}")
    digest = hashlib.sha256(base64.b64decode(blob)).digest()
    fp = "SHA256:" + base64.b64encode(digest).decode().rstrip("=")
    if expected.get(kind) != fp:
        raise SystemExit(f"fingerprint mismatch for {kind}: {fp}")
    seen[kind] = fp
if set(seen) != set(expected):
    raise SystemExit(f"host key set {sorted(seen)} != {sorted(expected)}")
PY
ok "pinned GitHub host keys match the published fingerprints"

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export MODERN_REPO_ROOT="$TMP/repo"
unset MODERN_TEST_FIXTURE MODERN_DEPLOY_KEY || true

if [ -z "$(deploy_key_file)" ] && [ "$(github_sync_url)" = "$GITHUB_HTTPS_URL" ]; then
    ok "no key uses the allowlisted HTTPS repo"
else
    err "missing key did not stay on HTTPS: $(github_sync_url)"
fi

new_key "$TMP/repo/secrets/github-deploy-key"
if [ "$(deploy_key_file)" = "$TMP/repo/secrets/github-deploy-key" ] \
    && [ "$(github_sync_url)" = "$GITHUB_SSH_URL" ]; then
    ok "build-machine key selects the allowlisted SSH repo"
else
    err "repo key not selected: $(deploy_key_file) $(github_sync_url)"
fi
# The address is a constant. A key file cannot retarget it.
case "$GITHUB_SSH_URL" in
    git@github.com:Gamesearch56/modern_dotfile.git) ok "SSH URL is this repo only" ;;
    *) err "SSH URL drifted: $GITHUB_SSH_URL" ;;
esac

new_key "$XDG_CONFIG_HOME/modern/deploy_key"
if [ "$(deploy_key_file)" = "$XDG_CONFIG_HOME/modern/deploy_key" ]; then
    ok "installed key wins over the build-machine key"
else
    err "installed key not preferred: $(deploy_key_file)"
fi

chmod 0644 "$XDG_CONFIG_HOME/modern/deploy_key"
if [ "$(deploy_key_file)" = "$TMP/repo/secrets/github-deploy-key" ]; then
    ok "group-readable key is ignored"
else
    err "loose key was trusted: $(deploy_key_file)"
fi
chmod 0600 "$XDG_CONFIG_HOME/modern/deploy_key"

ln -s "$TMP/repo/secrets/github-deploy-key" "$TMP/link-key"
export MODERN_TEST_FIXTURE=1 MODERN_DEPLOY_KEY="$TMP/link-key"
if [ -z "$(deploy_key_file)" ]; then
    ok "symlink key is ignored"
else
    err "symlink key was trusted: $(deploy_key_file)"
fi

bogus="$TMP/bogus"
printf 'not a key\n' >"$bogus"
chmod 0600 "$bogus"
export MODERN_DEPLOY_KEY="$bogus"
if [ -z "$(deploy_key_file)" ] && [ "$(github_sync_url)" = "$GITHUB_HTTPS_URL" ]; then
    ok "non-key file is ignored and stays on HTTPS"
else
    err "bogus file was trusted"
fi

spaced="$TMP/we ird/ke'y"
new_key "$spaced"
export MODERN_DEPLOY_KEY="$spaced"
cmd="$(github_ssh_command)" || err "ssh command failed"
python3 - "$cmd" "$spaced" "$ROOT/scripts/lib/github-known-hosts" <<'PY'
import shlex, sys
cmd, key, hosts = sys.argv[1:]
args = shlex.split(cmd)
need = {
    "-F": "/dev/null",
    "-i": key,
    "-o": None,
}
def opt(flag):
    return args[args.index(flag) + 1]
if opt("-F") != "/dev/null" or opt("-i") != key:
    raise SystemExit(f"identity args wrong: {args}")
opts = [args[i + 1] for i, a in enumerate(args) if a == "-o"]
for required in (
    "IdentitiesOnly=yes",
    "IdentityAgent=none",
    "StrictHostKeyChecking=yes",
    "GlobalKnownHostsFile=/dev/null",
    "BatchMode=yes",
    f"UserKnownHostsFile={hosts}",
):
    if required not in opts:
        raise SystemExit(f"missing {required} in {opts}")
PY
ok "ssh command pins this key and GitHub's host keys, including odd paths"

# Fixture mode must not pick up a real key in $HOME or the checkout.
unset MODERN_DEPLOY_KEY
export MODERN_TEST_FIXTURE=1
if [ -z "$(deploy_key_file)" ] && [ "$(github_sync_url)" = "$GITHUB_HTTPS_URL" ]; then
    ok "fixture mode ignores the real deploy keys"
else
    err "fixture saw a real key: $(deploy_key_file)"
fi

# desktop-sync records the command it will give git, and still fetches
# the fixture remote rather than GitHub.
bare="$TMP/remote.git"
clone="$TMP/clone"
git -c core.hooksPath=/dev/null init -q --bare "$bare"
git -c core.hooksPath=/dev/null init -q "$clone"
git -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.email=t@e -c user.name=t \
    -C "$clone" commit -q --allow-empty -m init
git -c core.hooksPath=/dev/null -C "$clone" tag v0.1.0
git -c core.hooksPath=/dev/null -C "$clone" remote add origin "$bare"
git -c core.hooksPath=/dev/null -C "$clone" push -q origin HEAD:refs/heads/main v0.1.0
log="$TMP/ssh-cmd"
export MODERN_DEPLOY_KEY="$spaced" MODERN_DESKTOP_REPO="$clone" MODERN_DESKTOP_REMOTE="$bare"
export MODERN_SSH_COMMAND_LOG="$log" XDG_RUNTIME_DIR="$TMP"
"$SYNC" status >/dev/null
python3 - "$log" "$spaced" <<'PY'
import pathlib, shlex, sys
text = pathlib.Path(sys.argv[1]).read_text().strip()
args = shlex.split(text)
if args[args.index("-i") + 1] != sys.argv[2]:
    raise SystemExit(f"desktop-sync ssh identity was {args}")
if "IdentitiesOnly=yes" not in text or "GlobalKnownHostsFile=/dev/null" not in text:
    raise SystemExit(text)
PY
ok "desktop-sync hands git only this deploy key"

unset MODERN_DEPLOY_KEY
: >"$log"
"$SYNC" status >/dev/null
if [ -z "$(tr -d '[:space:]' <"$log")" ]; then
    ok "desktop-sync without a key does not set an ssh command"
else
    err "unexpected ssh command: $(cat "$log")"
fi

src="$TMP/repo/secrets/github-deploy-key"
dest="$TMP/staged"
if stage_deploy_key "$dest" "$src" && [ "$(stat -c '%a' "$dest")" = 600 ] \
    && cmp -s "$src" "$dest"; then
    ok "ISO staging copies the key as mode 600"
else
    err "stage_deploy_key did not embed the key"
fi
ln -s "$src" "$TMP/stage-link"
if stage_deploy_key "$TMP/nope" "$TMP/stage-link" 2>/dev/null; then
    err "stage_deploy_key accepted a symlink"
else
    ok "ISO staging rejects a symlink"
fi
if stage_deploy_key "$TMP/absent-dest" "$TMP/does-not-exist" \
    && [ ! -e "$TMP/absent-dest" ]; then
    ok "ISO staging skips a missing key"
else
    err "missing key should not fail the build"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-deploy-key: ok\n'
