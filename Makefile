SHELL = /bin/bash
JOBS=2

LINUX_VER=4.14.94
LINUX_VER_MAJOR=${shell echo ${LINUX_VER} | cut -d '.' -f1,2}
LOCALVERSION=-0
UBOOT_VER=2018.09
APT_GPG_KEY=CEADE0CF01939B21

USBARMORY_REPO=https://raw.githubusercontent.com/inversepath/usbarmory/master
MXC_SCC2_REPO=https://github.com/inversepath/mxc-scc2
TARGET_IMG=usbarmory-debian_stretch-base_image-`date +%Y%m%d`.raw

.DEFAULT_GOAL := all

${TARGET_IMG}:
	truncate -s 3500MiB ${TARGET_IMG}
	/sbin/parted ${TARGET_IMG} --script mklabel msdos
	/sbin/parted ${TARGET_IMG} --script mkpart primary ext4 5M 100%

debian: ${TARGET_IMG}
	sudo /sbin/losetup /dev/loop0 ${TARGET_IMG} -o 5242880 --sizelimit 3500MiB
	sudo /sbin/mkfs.ext4 -F /dev/loop0
	sudo /sbin/losetup -d /dev/loop0
	mkdir -p rootfs
	sudo mount -o loop,offset=5242880 -t ext4 ${TARGET_IMG} rootfs/
	sudo qemu-debootstrap --arch=armhf --include=ssh,sudo,ntpdate,fake-hwclock,openssl,vim,nano,cryptsetup,lvm2,locales,less,cpufrequtils,isc-dhcp-server,haveged,whois,iw,wpasupplicant,dbus,apt-transport-https,dirmngr,ca-certificates stretch rootfs http://ftp.debian.org/debian/
	sudo install -m 755 -o root -g root conf/rc.local rootfs/etc/rc.local
	sudo install -m 644 -o root -g root conf/sources.list rootfs/etc/apt/sources.list
	sudo install -m 644 -o root -g root conf/dhcpd.conf rootfs/etc/dhcp/dhcpd.conf
	sudo install -m 644 -o root -g root conf/usbarmory.conf rootfs/etc/modprobe.d/usbarmory.conf
	sudo sed -i -e 's/INTERFACES=""/INTERFACES="usb0"/' rootfs/etc/default/isc-dhcp-server
	echo "tmpfs /tmp tmpfs defaults 0 0" | sudo tee rootfs/etc/fstab
	echo -e "\nUseDNS no" | sudo tee -a rootfs/etc/ssh/sshd_config
	echo "nameserver 8.8.8.8" | sudo tee rootfs/etc/resolv.conf
	sudo chroot rootfs systemctl mask getty-static.service
	sudo chroot rootfs systemctl mask display-manager.service
	sudo chroot rootfs systemctl mask hwclock-save.service
	sudo chroot rootfs apt-key adv --keyserver hkp://keys.gnupg.net --recv-keys ${APT_GPG_KEY}
	echo "ledtrig_heartbeat" | sudo tee -a rootfs/etc/modules
	echo "ci_hdrc_imx" | sudo tee -a rootfs/etc/modules
	echo "g_ether" | sudo tee -a rootfs/etc/modules
	echo -e 'auto usb0\nallow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2'| sudo tee -a rootfs/etc/network/interfaces
	echo "usbarmory" | sudo tee rootfs/etc/hostname
	echo "usbarmory  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a rootfs/etc/sudoers
	echo -e "127.0.1.1\tusbarmory" | sudo tee -a rootfs/etc/hosts
	sudo chroot rootfs /usr/sbin/useradd -s /bin/bash -p `sudo chroot rootfs mkpasswd -m sha-512 usbarmory` -m usbarmory
	sudo rm rootfs/etc/ssh/ssh_host_*
	sudo cp linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf.deb rootfs/tmp/
	sudo chroot rootfs /usr/bin/dpkg -i /tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf.deb
	sudo rm rootfs/tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf.deb
	sudo chroot rootfs /bin/bash -c "cd /boot ; ln -s zImage-${LINUX_VER}${LOCALVERSION}-usbarmory zImage ; ln -s imx53-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb imx53-usbarmory.dtb"
	sudo chroot rootfs apt-get clean
	sudo chroot rootfs fake-hwclock
	sudo rm rootfs/usr/bin/qemu-arm-static
	sudo umount rootfs

linux-${LINUX_VER}.tar.xz:
	wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-${LINUX_VER}.tar.xz -O linux-${LINUX_VER}.tar.xz
	wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-${LINUX_VER}.tar.sign -O linux-${LINUX_VER}.tar.sign

u-boot-${UBOOT_VER}.tar.bz2:
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2 -O u-boot-${UBOOT_VER}.tar.bz2
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2.sig -O u-boot-${UBOOT_VER}.tar.bz2.sig

linux-${LINUX_VER}/arch/arm/boot/zImage: linux-${LINUX_VER}.tar.xz
	unxz --keep linux-${LINUX_VER}.tar.xz
	gpg --verify linux-${LINUX_VER}.tar.sign
	tar xvf linux-${LINUX_VER}.tar && cd linux-${LINUX_VER}
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config
	cd linux-${LINUX_VER} && KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory LOCALVERSION=${LOCALVERSION} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j${JOBS} zImage modules imx53-usbarmory.dtb

u-boot-${UBOOT_VER}/u-boot.imx: u-boot-${UBOOT_VER}.tar.bz2
	gpg --verify u-boot-${UBOOT_VER}.tar.bz2.sig
	tar xvf u-boot-${UBOOT_VER}.tar.bz2
	cd u-boot-${UBOOT_VER} && make distclean
	cd u-boot-${UBOOT_VER} && make usbarmory_config
	cd u-boot-${UBOOT_VER} && CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm make -j${JOBS}

mxc-scc2-master.zip:
	wget ${MXC_SCC2_REPO}/archive/master.zip -O mxc-scc2-master.zip
	unzip mxc-scc2-master

linux: linux-${LINUX_VER}/arch/arm/boot/zImage

mxc-scc2: mxc-scc2-master.zip linux-${LINUX_VER}/arch/arm/boot/zImage
	cd mxc-scc2-master && make KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all

dtb: linux-${LINUX_VER}/arch/arm/boot/zImage
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-host.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-host.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-gpio.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-gpio.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-spi.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-spi.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-i2c.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-i2c.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-scc2.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-scc2.dts
	cd linux-${LINUX_VER} && KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory LOCALVERSION=${LOCALVERSION} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j${JOBS} imx53-usbarmory-host.dtb imx53-usbarmory-gpio.dtb imx53-usbarmory-spi.dtb imx53-usbarmory-i2c.dtb imx53-usbarmory-scc2.dtb

linux-deb: linux dtb mxc-scc2
	mkdir -p linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/{DEBIAN,boot,lib/modules}
	cat control_template | sed -e 's/XXXX/${LINUX_VER_MAJOR}/' | sed -e 's/YYYY/${LINUX_VER}${LOCALVERSION}/' > linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control
	cp -r linux-${LINUX_VER}/arch/arm/boot/zImage linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/zImage-${LINUX_VER}${LOCALVERSION}-usbarmory
	cp -r linux-${LINUX_VER}/.config linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/config-${LINUX_VER}${LOCALVERSION}-usbarmory
	cp -r linux-${LINUX_VER}/System.map linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/System.map-${LINUX_VER}${LOCALVERSION}-usbarmory
	cd linux-${LINUX_VER} && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm modules_install
	cd mxc-scc2-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-host.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-host-${LINUX_VER}${LOCALVERSION}.dtb
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-spi.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-spi-${LINUX_VER}${LOCALVERSION}.dtb
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-gpio.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-gpio-${LINUX_VER}${LOCALVERSION}.dtb
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-i2c.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-i2c-${LINUX_VER}${LOCALVERSION}.dtb
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-scc2.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/boot/imx53-usbarmory-scc2-${LINUX_VER}${LOCALVERSION}.dtb
	rm linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/{build,source}
	fakeroot dpkg-deb -b linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf.deb

u-boot: u-boot-${UBOOT_VER}/u-boot.imx

finalize: ${TARGET_IMG} u-boot-${UBOOT_VER}/u-boot.imx
	sudo dd if=u-boot-${UBOOT_VER}/u-boot.imx of=${TARGET_IMG} bs=512 seek=2 conv=fsync conv=notrunc
	xz -k ${TARGET_IMG}
	zip -j ${TARGET_IMG}.zip ${TARGET_IMG}

all: linux-deb debian u-boot finalize

clean:
	-rm -r linux-${LINUX_VER}*
	-rm -r u-boot-${UBOOT_VER}*
	-rm -r linux-image-${LINUX_VER_MAJOR}-usbarmory_${LINUX_VER}${LOCALVERSION}_armhf*
	-rm -r mxc-scc2-master*
	-rm usbarmory-debian_stretch-base_image-*.raw
	-rmdir rootfs
