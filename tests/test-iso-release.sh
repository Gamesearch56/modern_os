#!/usr/bin/env bash
# scripts/iso-release.sh: a public ISO with a deploy key never leaves the
# machine, the upload is checked against GitHub's digest, a re-run keeps
# one Download section, and iso-build --public leaves the key out.
# Single-quoted $ is literal code to grep for or to write into stubs.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-iso-release: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-iso-release: ok %s\n' "$*"; }
has() { if grep -Fq -- "$1" "$2"; then ok "$3"; else err "$3"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-iso-release-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

has 'rm -f "$AIROOTFS_OUT/usr/lib/modern/deploy_key"' "$ROOT/scripts/iso-build.sh" \
    "iso-build drops a key left over from an earlier private build"
has 'if [ -n "$PUBLIC" ]; then' "$ROOT/scripts/iso-build.sh" "iso-build --public skips the deploy key"
has 'iso-release.sh vX.Y.Z' "$ROOT/docs/GIT.md" "docs/GIT.md describes the release ISO"

# shellcheck source=../scripts/lib/iso-release.sh
source "$ROOT/scripts/lib/iso-release.sh"
printf '## [1.0.0]\n\n- thing\n' >"$TMP/body"
block="$(iso_download_block https://github.com/o/r v1.0.0 1073741824 abc FPR)"
iso_notes_with_download "$block" <"$TMP/body" >"$TMP/once"
iso_notes_with_download "$block" <"$TMP/once" >"$TMP/twice"
if cmp -s "$TMP/once" "$TMP/twice" && [ "$(grep -c '### Download' "$TMP/twice")" = 1 ] \
    && head -1 "$TMP/twice" | grep -Fxq '## [1.0.0]' \
    && tail -1 "$TMP/twice" | grep -Fxq "$ISO_NOTES_END" \
    && grep -Fq -- '- thing' "$TMP/twice"; then
    ok "the Download section follows the notes and a re-run replaces it"
else
    err "release notes after two runs: $(cat "$TMP/twice")"
fi
has 'releases/download/v1.0.0/modernos-x86_64.iso' "$TMP/once" "notes link the stable asset name"

if ! command -v mksquashfs >/dev/null 2>&1 || ! command -v xorriso >/dev/null 2>&1 \
    || ! command -v unsquashfs >/dev/null 2>&1; then
    ok "skipping image checks (no squashfs-tools/xorriso)"
    exit "$FAIL"
fi

make_iso() {
    local name="$1" root="$TMP/$1-root" tree="$TMP/$1-tree"
    mkdir -p "$root/usr/lib/modern" "$root/usr/lib/python3/secrets-ok" "$tree/arch/x86_64"
    printf 'live\n' >"$root/usr/lib/modern/iso-pin"
    printf 'stdlib\n' >"$root/usr/lib/python3/secrets.py"
    [ "$name" = clean ] || printf 'KEY\n' >"$root/usr/lib/modern/deploy_key"
    mksquashfs "$root" "$tree/arch/x86_64/airootfs.sfs" -quiet -noappend >/dev/null
    xorriso -as mkisofs -o "$TMP/$name.iso" "$tree" >/dev/null 2>&1
}
make_iso clean
make_iso leaky
if [ "$(iso_leaks "$TMP/leaky.iso")" = /usr/lib/modern/deploy_key ]; then
    ok "the leak check finds the deploy key inside the squashfs"
else
    err "leaky image: $(iso_leaks "$TMP/leaky.iso" || true)"
fi
if out="$(iso_leaks "$TMP/clean.iso")" && [ -z "$out" ]; then
    ok "a clean image passes, secrets.py is not a credential"
else
    err "clean image flagged: $out"
fi
printf 'not an iso' >"$TMP/junk.iso"
if iso_leaks "$TMP/junk.iso" >/dev/null 2>&1; then
    err "an unreadable image passed the leak check"
else
    ok "an unreadable image fails instead of passing"
fi

repo="$TMP/repo"
mkdir -p "$repo/scripts/lib" "$repo/docs" "$TMP/bin"
cp "$ROOT/scripts/iso-release.sh" "$repo/scripts/"
cp "$ROOT/scripts/lib/iso-release.sh" "$repo/scripts/lib/"
printf 'public key\n' >"$repo/docs/release-key.asc"
git -C "$repo" init -q
git -C "$repo" add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
git -C "$repo" tag v9.9.9
cat >"$TMP/bin/gpg" <<'EOF'
#!/usr/bin/env bash
case " $* " in
    *" --show-keys "*) echo 'fpr:::::::::ABCDEF0123:' ;;
    *" --dearmor "*) cat ;;
    *" --detach-sign "*) while [ "$1" != --output ]; do shift; done; echo sig >"$2" ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/gpgv"
printf '#!/usr/bin/env bash\necho "sudo $*" >>"$GH_LOG"\n' >"$TMP/bin/sudo"
cat >"$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >>"$GH_LOG"
case "$1 $2 $*" in
    "repo view "*nameWithOwner*) echo o/r ;;
    "repo view "*visibility*) echo PUBLIC ;;
    "release view "*--json*) if [ -f "$NOTES" ]; then cat "$NOTES"; else printf '## [9.9.9]\n- thing\n'; fi ;;
    "release edit "*) while [ "$1" != --notes-file ]; do shift; done; cp "$2" "$NOTES" ;;
    "api "*) if grep -q 'upload .*modernos-x86_64.iso' "$GH_LOG"; then
                 echo "sha256:$(sha256sum "$UP_ISO" | cut -d' ' -f1)"
             else echo none; fi ;;
esac
EOF
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" GH_LOG="$TMP/gh.log" NOTES="$TMP/notes.md" UP_ISO="$TMP/clean.iso"

if "$repo/scripts/iso-release.sh" v9.9.9 --iso "$TMP/leaky.iso" --no-archive 2>"$TMP/leak.err"; then
    err "a leaking image was released"
elif grep -q 'credential: /usr/lib/modern/deploy_key' "$TMP/leak.err" \
    && ! grep -Eq 'gh release (upload|edit)' "$GH_LOG"; then
    ok "a leaking image stops before anything is uploaded"
else
    err "leak refusal: $(cat "$TMP/leak.err")"
fi
if "$repo/scripts/iso-release.sh" v9.9.9 --iso "$TMP/clean.iso" --with-deploy-key --no-archive 2>"$TMP/nokey.err"; then
    err "--with-deploy-key released an image without the key"
elif grep -q 'no deploy key at' "$TMP/nokey.err"; then
    ok "--with-deploy-key refuses an image that lacks the key"
else
    err "--with-deploy-key on a keyless image: $(cat "$TMP/nokey.err")"
fi
: >"$GH_LOG"
if UP_ISO="$TMP/leaky.iso" "$repo/scripts/iso-release.sh" v9.9.9 --iso "$TMP/leaky.iso" \
        --with-deploy-key --no-archive 2>"$TMP/withkey.err" \
    && grep -q 'carries the deploy key, as asked' "$TMP/withkey.err"; then
    ok "--with-deploy-key lets exactly the deploy key through"
else
    err "--with-deploy-key: $(cat "$TMP/withkey.err")"
fi
rm -f "$NOTES"

: >"$GH_LOG"
if "$repo/scripts/iso-release.sh" v9.9.9 --iso "$TMP/clean.iso" --no-archive 2>"$TMP/run.err" \
    && grep -q "gh release upload v9.9.9 .*/modernos-x86_64.iso .*/SHA256SUMS .*/SHA256SUMS.asc" "$GH_LOG" \
    && grep -q "GitHub's SHA-256 matches" "$TMP/run.err" \
    && ! grep -q '^sudo' "$GH_LOG"; then
    ok "a clean image uploads with its sums and signature and is checked against GitHub"
else
    err "release run: $(cat "$TMP/run.err")"
fi
if "$repo/scripts/iso-release.sh" v9.9.9 --iso "$TMP/clean.iso" --no-archive 2>"$TMP/rerun.err" \
    && grep -q 'GitHub already has this image' "$TMP/rerun.err" \
    && [ "$(grep -c '### Download' "$NOTES")" = 1 ]; then
    ok "a re-run skips the upload and keeps one Download section"
else
    err "re-run: $(cat "$TMP/rerun.err")"
fi
if (cd "$repo/iso/out/release/v9.9.9" && sha256sum -c --quiet SHA256SUMS); then
    ok "SHA256SUMS matches the staged image"
else
    err "SHA256SUMS does not match"
fi

exit "$FAIL"
