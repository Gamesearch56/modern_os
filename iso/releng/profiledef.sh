#!/usr/bin/env bash
# archiso profile overlay. iso-build.sh copies releng + this file.
# mkarchiso writes only --out (iso/out/). Never run provision-iso.sh
# on a machine you live on.
iso_name="modernos"
iso_label="MODERNOS"
iso_publisher="ModernOS"
iso_application="ModernOS live installer"
iso_version="${ISO_VERSION:-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)}"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/lib/modern/calamares-late.sh"]="0:0:755"
  ["/usr/lib/modern/live-setup.sh"]="0:0:755"
  ["/usr/lib/modern/live-i18n.sh"]="0:0:755"
  ["/usr/lib/modern/live-session.sh"]="0:0:755"
  ["/usr/lib/modern/live-calamares.sh"]="0:0:755"
  ["/usr/lib/modern/live-xdg-open.sh"]="0:0:755"
  ["/usr/lib/modern/live-xkb-filter.py"]="0:0:755"
  ["/usr/lib/modern/live-wifi-sim.sh"]="0:0:755"
  ["/usr/lib/modern/live-wifi-wl.sh"]="0:0:755"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/etc/sudoers.d/99-liveuser"]="0:0:440"
)
