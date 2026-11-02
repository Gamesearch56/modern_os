#!/usr/bin/env bash
# Light Steam writes library keys without dropping the rest of the file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$ROOT/scripts/steam-light.py"
FAIL=0
err() { printf 'test-steam-light: FAIL %s\n' "$*" >&2; FAIL=1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-steam-light-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/steam/userdata/1/config" "$TMP/state"
cat >"$TMP/steam/userdata/1/config/localconfig.vdf" <<'EOF'
"UserLocalConfigStore"
{
	"FavoriteServersLastUpdateTime"		"5"
	"KeepMe"		"yes"
}
EOF
cat >"$TMP/steam/registry.vdf" <<'EOF'
"Registry"
{
	"HKCU"
	{
		"Software"
		{
			"Valve"
			{
				"Steam"
				{
					"AutoLoginUser"		"player"
				}
			}
		}
	}
}
EOF

MODERN_STEAM_ROOT="$TMP/steam" MODERN_STATE_DIR="$TMP/state" \
    python3 "$PY" apply
localcfg="$TMP/steam/userdata/1/config/localconfig.vdf"
grep -q 'LibraryLowPerfMode"		"1"' "$localcfg" || err "low performance mode was not set"
grep -q 'KeepMe"		"yes"' "$localcfg" || err "unrelated key was dropped"
grep -q 'GPUAccelWebViewsV3"		"0"' "$TMP/steam/registry.vdf" || err "web-view gpu accel stays on"
grep -q 'unShaderBackgroundProcessingThreads 1' "$TMP/steam/steam_dev.cfg" || err "shader thread cap missing"
MODERN_STEAM_ROOT="$TMP/steam" MODERN_STATE_DIR="$TMP/state" \
    python3 "$PY" apply
count="$(grep -c 'LibraryLowPerfMode' "$localcfg" || true)"
[ "$count" = "1" ] || err "low performance mode was duplicated"
MODERN_STEAM_ROOT="$TMP/steam" MODERN_STATE_DIR="$TMP/state" \
    python3 "$PY" clear
grep -q 'LibraryLowPerfMode"		"0"' "$localcfg" || err "low performance mode was not restored"
grep -q 'GPUAccelWebViewsV3"		"1"' "$TMP/steam/registry.vdf" || err "web-view gpu accel was not restored"
if [ -f "$TMP/steam/steam_dev.cfg" ] && grep -q 'modern:steamLight' "$TMP/steam/steam_dev.cfg"; then
    err "shader cap was left behind"
fi
[ ! -f "$TMP/state/modern/steam-light" ] || err "marker was left behind"

jq -e '.gaming.steamLight == false and .gaming.lowEnd == false' \
    "$ROOT/stow/modern/.config/modern/config.default.json" >/dev/null \
    || err "defaults must stay off"
grep -q 'steam)' "$ROOT/scripts/modern" || err "modern steam is not wired"
grep -q -- '-cef-disable-gpu' "$ROOT/scripts/steam" || err "steam wrapper missing gpu flag"
grep -Fq 'modern-steam-light' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    || err "steam window relief is not loaded"
grep -Fq 'modules.steam_light' "$ROOT/stow/hypr/.config/hypr/hyprland.lua" \
    && err "steam_light must not be a separate module"
for lang in en de; do
    jq -e '.settings.fields.steamLight and .settings.fields.lowEnd and .settings.hints.steamLight and .settings.hints.lowEnd and .settings.gaming.slow' \
        "$ROOT/stow/modern/.config/modern/translations/${lang}.json" >/dev/null \
        || err "copy missing in ${lang}"
done

# Steam needs a 32-bit Vulkan driver; unnamed, pacman installs
# lib32-vulkan-radeon on every GPU.
for gpu in "$ROOT"/install/manifests/00-hw-gpu-*.txt; do
    family="${gpu##*/00-hw-gpu-}"
    apps="$ROOT/install/manifests/30-hw-gpu-${family}"
    grep -Eq '^lib32-(vulkan-|nvidia-utils)' "$apps" 2>/dev/null \
        || err "no 32-bit Vulkan driver for Steam on ${family%.txt} (30-hw-gpu-${family})"
done
grep -Fq '30-hw-gpu-' "$ROOT/install/install.sh" || err "install.sh must install 30-hw-gpu-*"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-steam-light: ok\n'
