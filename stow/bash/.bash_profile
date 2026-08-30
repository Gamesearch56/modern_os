# Login shells skip .bashrc unless we source it here (Kitty often starts
# a login shell).
if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bashrc"
fi
