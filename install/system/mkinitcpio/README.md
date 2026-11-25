# mkinitcpio drop-in — staged, never applied

Nothing in this directory is copied to `/etc/mkinitcpio.conf.d/` or
merged into `/etc/mkinitcpio.conf` by `install.sh`. Rebuilding the
initramfs is a gated operator step (docs/ISOLATION.md).

When you *do* enable the Plymouth splash, `kms` must appear **before**
`plymouth` in `HOOKS`. Plymouth needs a working framebuffer; `kms` loads
the kernel mode-setting driver that provides it. The typical order:

```
HOOKS=(base udev autodetect microcode kms keyboard keymap consolefont plymouth block filesystems fsck)
```

Putting `plymouth` before `kms` yields a blank or late splash (and, on
some GPUs, a hang until the real root takes over). Do not drop a
`HOOKS=` override here that silently rewrites the host's mkinitcpio
config — edit `/etc/mkinitcpio.conf` (or a file you place under
`/etc/mkinitcpio.conf.d/`) yourself, then `mkinitcpio -P`.
