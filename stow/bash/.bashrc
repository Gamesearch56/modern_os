# Why this file exists: interactive shell conveniences for the modern
# desktop. Theme/toolkit variables are owned by matugen + config.json,
# not here — QT_QPA_PLATFORM=xcb and a hardcoded GTK_THEME would force
# XWayland and fight the token pipeline (docs/DECISIONS.md #5).
#
# Stow target: $HOME/.bashrc for the install user (never the live
# daily-driver account). Machine-local extras go in bashrc.local.

export EDITOR="${EDITOR:-nvim}"

_modern_local="${XDG_CONFIG_HOME:-$HOME/.config}/modern/bashrc.local"
if [ -f "$_modern_local" ]; then
    # shellcheck source=/dev/null
    . "$_modern_local"
fi
unset _modern_local

# Non-interactive shells (scp, ssh remote-cmd) should not grow aliases
# or print a fetch.
case $- in
    *i*) ;;
    *) return ;;
esac

alias vim=nvim
alias ls='ls -alh --color=auto'
alias grep='grep --color=auto'
alias wallpaper='modern wallpaper picker'
alias reload_ui='modern shell reload'
alias system_language='echo use Settings'

load() { yay -S --needed -- "$@"; }
unload() { yay -Rns -- "$@"; }

system_cleanup() {
    yay -Yc
    paccache -r
}

system_find() {
    pacman -F -- "$@"
}

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
