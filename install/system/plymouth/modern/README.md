# Plymouth theme `modern`

Boot and shutdown use this solid surface, a large ModernOS word, and a
ring of dots under it. The colors are the installer palette (`#141218`,
`#D0BCFF`). There is no wallpaper in the theme, so a missing picture
cannot break the initramfs. The script only calls functions the Plymouth
script module actually has (`Image.Text`, `Sprite`, `Math`). `Image.Box`
is not one of them, and a call it does not know leaves the screen black.

`install/system/plymouth/apply.sh` copies these two files into place,
adds the `plymouth` hook after `kms`, and appends the splash kernel
line. `provision-iso.sh` and a system update source it. The initramfs
is rebuilt only when the theme or the hook changed.

`scripts/theme-apply.sh` and `scripts/wallpaper-sync.sh` do not call
it. A palette or wallpaper change must stay a file write.
