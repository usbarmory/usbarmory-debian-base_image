#!/bin/bash
# Based on:
# https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/blob/main/PKGBUILD

scriptlinuxdir=$(realpath $1)
builddir=$(realpath $2)

echo "Installing build files..."
install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map vmlinux
install -Dt "$builddir/kernel" -m644 kernel/Makefile
install -Dt "$builddir/arch/arm" -m644 arch/arm/Makefile
cp -t "$builddir" -a scripts
echo "Overwrite executable files with arm native ones..."
cd $scriptlinuxdir && find scripts -type f -executable -exec install -Dm755 {} "${builddir}/{}" \; && cd -

echo "Installing headers..."
cp -t "$builddir" -a include
cp -t "$builddir/arch/arm" -a arch/arm/include
install -Dt "$builddir/arch/arm/kernel" -m644 arch/arm/kernel/asm-offsets.s

install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

# https://bugs.archlinux.org/task/13146
install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

# https://bugs.archlinux.org/task/20402
install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

# https://bugs.archlinux.org/task/71392
install -Dt "$builddir/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

echo "Installing KConfig files..."
find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

echo "Removing unneeded architectures..."
for arch in "$builddir"/arch/*/; do
  [[ $arch = */arm/ ]] && continue
  echo "Removing $(basename "$arch")"
  rm -r "$arch"
done

echo "Removing documentation..."
rm -r "$builddir/Documentation"

echo "Removing broken symlinks..."
find -L "$builddir" -type l -printf 'Removing %P\n' -delete

echo "Removing loose objects..."
find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete
