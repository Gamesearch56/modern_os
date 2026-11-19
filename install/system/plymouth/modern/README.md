# Plymouth theme `modern`

Boot and shutdown use this solid surface and progress bar. The colors
are the installer palette (`#141218`, `#D0BCFF`). There is no wallpaper
in the theme, so a missing picture cannot break the initramfs.

`install/system/plymouth/apply.sh` copies these two files into place,
adds the `plymouth` hook after `kms`, and appends the splash kernel
line. `provision-iso.sh` sources it and rebuilds the initramfs once.
Running the script itself does that rebuild on an installed machine.

`install.sh`, `scripts/theme-apply.sh`, and `scripts/wallpaper-sync.sh`
do not call it. A palette or wallpaper change must stay a file write.
