# Plymouth theme `modern` — staged only

This directory is copied to `/usr/share/plymouth/themes/modern/` by an
explicit operator step, never by `install.sh`. See `docs/ISOLATION.md`.

Colors in `modern.script` are placeholders. `scripts/plymouth-sync.sh`
reads `~/.config/modern/tokens.json` and writes a generated script using
the current `surface` / `primary` tokens. Regenerating the splash is a
theme-*profile* change (or Settings → Design "Sync boot screen"), not a
wallpaper pick — the theme lives in the initramfs, so a live rewrite
would mean `mkinitcpio -P` on every wallpaper change (docs/DECISIONS.md
#13).

`plymouth-sync.sh` never runs `mkinitcpio`. After copying the generated
files into `/usr/share/plymouth/themes/modern/`, rebuild the initramfs
yourself:

```
sudo cp -r install/system/plymouth/modern /usr/share/plymouth/themes/
sudo plymouth-set-default-theme -R modern   # this *does* run mkinitcpio
```

Or copy the generated script from `$XDG_STATE_HOME/modern/plymouth/` over
the staged `modern.script` and run `mkinitcpio -P` separately.
