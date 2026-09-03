#!/usr/bin/env bash
# Runs inside the ISO workflow's Arch container, never on a developer
# machine — local images are `sudo ./scripts/iso-build.sh --mkarchiso`.
#
# The workflow used to set `container:` on the job itself. It no longer
# does: GitHub guarantees only 14G free on ubuntu-latest and mkarchiso
# needs more, and the preinstalled toolchains worth deleting live on the
# host where a containerised step cannot see them. So the job frees space
# on the host, checks out there, and calls this through `docker run`.
set -euo pipefail

: "${GITHUB_WORKSPACE:?must be passed through to the container}"
: "${ISO_OUT:?must be passed through to the container}"
: "${TAG:?must be passed through to the container}"

# qemu-img is its own package — qemu-system-x86 no longer pulls it in,
# and the smoke test creates vm-disk.qcow2 with it after mkarchiso.
pacman -Syu --noconfirm --needed archiso base-devel git python jq sudo \
    qemu-system-x86 qemu-img edk2-ovmf qt6-tools

# The workspace belongs to the runner user while this container is root,
# and checkout's own safe.directory went into a temporary global config
# that is long gone. Without this, git refuses the repository that
# iso-build.sh clones the pinned bundle from.
#
# Both entries are needed. Commands run inside the worktree check the
# worktree path, but `git clone <path>` resolves the source to
# <path>/.git and checks that instead — whitelisting only the first lets
# the preflight pass and the clone still fail on dubious ownership.
git config --global --add safe.directory "$GITHUB_WORKSPACE"
git config --global --add safe.directory "$GITHUB_WORKSPACE/.git"

df -h "$ISO_OUT" /tmp || true

"$GITHUB_WORKSPACE/scripts/iso-build.sh" --mkarchiso --out "$ISO_OUT" --tag "$TAG"
find "$ISO_OUT" -name '*.iso' -ls

MODERN_ISO_OUT="$ISO_OUT" MODERN_ISO_QEMU_MEM=4G MODERN_ISO_QEMU_SMP=2 \
    "$GITHUB_WORKSPACE/scripts/test-iso-qemu-smoke.sh"

df -h "$ISO_OUT" /tmp || true

# upload-artifact runs as the runner user, outside this container, and
# everything above was written by root.
chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$ISO_OUT"
