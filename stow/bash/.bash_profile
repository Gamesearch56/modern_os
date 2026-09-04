# Login shells skip .bashrc unless we source it here (Kitty often starts
# a login shell).
if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bashrc"
fi

# Getty login on VT1 starts this desktop with start-hyprland (not the
# Hyprland binary). greetd already execs that wrapper and never uses
# this file as a login shell. SSH and extra TTYs stay a prompt.
# Toolkit/session vars come from modules/env.lua.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    case "$(tty 2>/dev/null || true)" in
        /dev/tty1)
            exec start-hyprland
            ;;
    esac
fi
