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
alias ll='ls -alh --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias wallpaper='modern wallpaper picker'
alias reload_ui='modern ui reload'
alias reload_quickshell='modern shell reload'
alias find='find . -iname'
alias system_update='modern update'
alias system_cleanup='modern cleanup'
alias system_find='modern pkg find'
alias system_fix='modern repair'
alias fsr_on='optiscaler.sh on'
alias fsr_off='optiscaler.sh off'

# SSH
alias connect_macbook='kitty +kitten ssh bastianweigand@192.168.178.103'

shopt -s histappend checkwinsize
HISTSIZE=5000
HISTFILESIZE=20000

# shellcheck source=/dev/null
[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

load() { yay -S --needed -- "$@"; }
unload() { yay -Rns -- "$@"; }

if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
    echo ""
fi
