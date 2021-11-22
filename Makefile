SHELL = /bin/bash
JOBS=2

LINUX_VER=5.10.78
LINUX_VER_MAJOR=${shell echo ${LINUX_VER} | cut -d '.' -f1,2}
KBUILD_BUILD_USER=usbarmory
KBUILD_BUILD_HOST=f-secure-foundry
BUILD_USER=usbarmory
BUILD_HOST=f-secure-foundry
LOCALVERSION=-0
UBOOT_VER=2021.10
ARMORYCTL_VER=1.2
CRUCIBLE_VER=2021.05.03
APT_GPG_KEY=CEADE0CF01939B21

USBARMORY_REPO=https://raw.githubusercontent.com/f-secure-foundry/usbarmory/master
ARMORYCTL_REPO=https://github.com/f-secure-foundry/armoryctl
CRUCIBLE_REPO=https://github.com/f-secure-foundry/crucible
MXC_SCC2_REPO=https://github.com/f-secure-foundry/mxc-scc2
MXS_DCP_REPO=https://github.com/f-secure-foundry/mxs-dcp
CAAM_KEYBLOB_REPO=https://github.com/f-secure-foundry/caam-keyblob
IMG_VERSION=${V}-${BOOT_PARSED}-debian_bullseye-base_image-$(shell /bin/date -u "+%Y%m%d")
LOSETUP_DEV=$(shell sudo /sbin/losetup -f)

.DEFAULT_GOAL := release

V ?= mark-two
BOOT ?= uSD
BOOT_PARSED=$(shell echo "${BOOT}" | tr '[:upper:]' '[:lower:]')

check_version:
	@if test "${V}" = "mark-one"; then \
		if test "${BOOT}" != "uSD"; then \
			echo "invalid target, mark-one BOOT options are: uSD"; \
			exit 1; \
		elif test "${IMX}" != "imx53"; then \
			echo "invalid target, mark-one IMX options are: imx53"; \
			exit 1; \
		fi \
	elif test "${V}" = "mark-two"; then \
		if test "${BOOT}" != "uSD" && test "${BOOT}" != eMMC; then \
			echo "invalid target, mark-two BOOT options are: uSD, eMMC"; \
			exit 1; \
		elif test "${IMX}" != "imx6ul" && test "${IMX}" != "imx6ulz"; then \
			echo "invalid target, mark-two IMX options are: imx6ul, imx6ulz"; \
			exit 1; \
		fi \
	else \
		echo "invalid target - V options are: mark-one, mark-two"; \
		exit 1; \
	fi
	@echo "target: USB armory V=${V} IMX=${IMX} BOOT=${BOOT}"

#### u-boot ####

u-boot-${UBOOT_VER}.tar.bz2:
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2 -O u-boot-${UBOOT_VER}.tar.bz2
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2.sig -O u-boot-${UBOOT_VER}.tar.bz2.sig

u-boot-${UBOOT_VER}/u-boot.bin: check_version u-boot-${UBOOT_VER}.tar.bz2
	gpg --verify u-boot-${UBOOT_VER}.tar.bz2.sig
	tar xfm u-boot-${UBOOT_VER}.tar.bz2
	cd u-boot-${UBOOT_VER} && make distclean
	@if test "${V}" = "mark-one"; then \
		cd u-boot-${UBOOT_VER} && \
		wget ${USBARMORY_REPO}/software/u-boot/0001-Fix-microSD-detection-for-USB-armory-Mk-I.patch && \
		patch -p1 < 0001-Fix-microSD-detection-for-USB-armory-Mk-I.patch && \
		make usbarmory_config; \
	elif test "${V}" = "mark-two"; then \
		cd u-boot-${UBOOT_VER} && \
		wget ${USBARMORY_REPO}/software/u-boot/0001-ARM-mx6-add-support-for-USB-armory-Mk-II-board.patch && \
		patch -p1 < 0001-ARM-mx6-add-support-for-USB-armory-Mk-II-board.patch && \
		make usbarmory-mark-two_defconfig; \
		if test "${BOOT}" = "eMMC"; then \
			sed -i -e 's/CONFIG_SYS_BOOT_DEV_MICROSD=y/# CONFIG_SYS_BOOT_DEV_MICROSD is not set/' .config; \
			sed -i -e 's/# CONFIG_SYS_BOOT_DEV_EMMC is not set/CONFIG_SYS_BOOT_DEV_EMMC=y/' .config; \
		fi \
	fi
	cd u-boot-${UBOOT_VER} && CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm make -j${JOBS}

#### debian ####

DEBIAN_DEPS := check_version
DEBIAN_DEPS += linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
DEBIAN_DEPS += linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
DEBIAN_DEPS += armoryctl_${ARMORYCTL_VER}_armhf.deb crucible_${CRUCIBLE_VER}_armhf.deb
usbarmory-${IMG_VERSION}.raw: $(DEBIAN_DEPS)
	truncate -s 3500MiB usbarmory-${IMG_VERSION}.raw
	sudo /sbin/parted usbarmory-${IMG_VERSION}.raw --script mklabel msdos
	sudo /sbin/parted usbarmory-${IMG_VERSION}.raw --script mkpart primary ext4 5M 100%
	sudo /sbin/losetup $(LOSETUP_DEV) usbarmory-${IMG_VERSION}.raw -o 5242880 --sizelimit 3500MiB
	sudo /sbin/mkfs.ext4 -F $(LOSETUP_DEV)
	sudo /sbin/losetup -d $(LOSETUP_DEV)
	mkdir -p rootfs
	sudo mount -o loop,offset=5242880 -t ext4 usbarmory-${IMG_VERSION}.raw rootfs/
	sudo update-binfmts --enable qemu-arm
	sudo qemu-debootstrap \
		--include=ssh,sudo,ntpdate,fake-hwclock,openssl,vim,nano,cryptsetup,lvm2,locales,less,cpufrequtils,isc-dhcp-server,haveged,rng-tools,whois,iw,wpasupplicant,dbus,apt-transport-https,dirmngr,ca-certificates,u-boot-tools,mmc-utils,gnupg,libpam-systemd \
		--arch=armhf bullseye rootfs http://deb.debian.org/debian/
	sudo install -m 755 -o root -g root conf/rc.local rootfs/etc/rc.local
	sudo install -m 644 -o root -g root conf/sources.list rootfs/etc/apt/sources.list
	sudo install -m 644 -o root -g root conf/dhcpd.conf rootfs/etc/dhcp/dhcpd.conf
	sudo install -m 644 -o root -g root conf/usbarmory.conf rootfs/etc/modprobe.d/usbarmory.conf
	sudo sed -i -e 's/INTERFACESv4=""/INTERFACESv4="usb0"/' rootfs/etc/default/isc-dhcp-server
	echo "tmpfs /tmp tmpfs defaults 0 0" | sudo tee rootfs/etc/fstab
	echo -e "\nUseDNS no" | sudo tee -a rootfs/etc/ssh/sshd_config
	echo "nameserver 8.8.8.8" | sudo tee rootfs/etc/resolv.conf
	sudo chroot rootfs systemctl mask getty-static.service
	sudo chroot rootfs systemctl mask display-manager.service
	sudo chroot rootfs systemctl mask hwclock-save.service
	@if test "${V}" = "mark-one"; then \
		sudo chroot rootfs systemctl mask rng-tools.service; \
	fi
	@if test "${V}" = "mark-two"; then \
		sudo chroot rootfs systemctl mask haveged.service; \
	fi
	sudo wget https://f-secure-foundry.github.io/keys/gpg-andrej.asc -O rootfs/tmp/gpg-andrej.asc
	sudo wget https://f-secure-foundry.github.io/keys/gpg-andrea.asc -O rootfs/tmp/gpg-andrea.asc
	sudo chroot rootfs apt-key add /tmp/gpg-andrej.asc
	sudo chroot rootfs apt-key add /tmp/gpg-andrea.asc
	echo "ledtrig_heartbeat" | sudo tee -a rootfs/etc/modules
	echo "ci_hdrc_imx" | sudo tee -a rootfs/etc/modules
	echo "g_ether" | sudo tee -a rootfs/etc/modules
	echo "i2c-dev" | sudo tee -a rootfs/etc/modules
	echo -e 'auto usb0\nallow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2'| sudo tee -a rootfs/etc/network/interfaces
	echo "usbarmory" | sudo tee rootfs/etc/hostname
	echo "usbarmory  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a rootfs/etc/sudoers
	echo -e "127.0.1.1\tusbarmory" | sudo tee -a rootfs/etc/hosts
# the hash matches password 'usbarmory'
	sudo chroot rootfs /usr/sbin/useradd -s /bin/bash -p '$$6$$bE13Mtqs3F$$VvaDyPBE6o/Ey0sbyIh5/8tbxBuSiRlLr5rai5M7C70S22HDwBvtu2XOFsvmgRMu.tPdyY6ZcjRrbraF.dWL51' -m usbarmory
	sudo rm rootfs/etc/ssh/ssh_host_*
	sudo cp linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb rootfs/tmp/
	sudo chroot rootfs /usr/bin/dpkg -i /tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
	sudo cp linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb rootfs/tmp/
	sudo chroot rootfs /usr/bin/dpkg -i /tmp/linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
	sudo rm rootfs/tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
	@if test "${V}" = "mark-two"; then \
		sudo cp armoryctl_${ARMORYCTL_VER}_armhf.deb rootfs/tmp/; \
		sudo chroot rootfs /usr/bin/dpkg -i /tmp/armoryctl_${ARMORYCTL_VER}_armhf.deb; \
		sudo rm rootfs/tmp/armoryctl_${ARMORYCTL_VER}_armhf.deb; \
		sudo cp crucible_${CRUCIBLE_VER}_armhf.deb rootfs/tmp/; \
		sudo chroot rootfs /usr/bin/dpkg -i /tmp/crucible_${CRUCIBLE_VER}_armhf.deb; \
		sudo rm rootfs/tmp/crucible_${CRUCIBLE_VER}_armhf.deb; \
		if test "${BOOT}" = "uSD"; then \
			echo "/dev/mmcblk0 0x100000 0x2000 0x2000" | sudo tee rootfs/etc/fw_env.config; \
		else \
			echo "/dev/mmcblk1 0x100000 0x2000 0x2000" | sudo tee rootfs/etc/fw_env.config; \
		fi \
	fi
	sudo chroot rootfs apt-get clean
	sudo chroot rootfs fake-hwclock
	sudo rm rootfs/usr/bin/qemu-arm-static
	sudo umount rootfs

#### debian-xz ####

usbarmory-${IMG_VERSION}.raw.xz: usbarmory-${IMG_VERSION}.raw u-boot-${UBOOT_VER}/u-boot.bin
	sudo dd if=u-boot-${UBOOT_VER}/u-boot-dtb.imx of=usbarmory-${IMG_VERSION}.raw bs=512 seek=2 conv=fsync conv=notrunc
	xz -k usbarmory-${IMG_VERSION}.raw

#### linux ####

linux-${LINUX_VER}.tar.xz:
	wget https://www.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.xz -O linux-${LINUX_VER}.tar.xz
	wget https://www.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.sign -O linux-${LINUX_VER}.tar.sign

linux-${LINUX_VER}/arch/arm/boot/zImage: check_version linux-${LINUX_VER}.tar.xz
	@if [ ! -d "linux-${LINUX_VER}" ]; then \
		unxz --keep linux-${LINUX_VER}.tar.xz; \
		gpg --verify linux-${LINUX_VER}.tar.sign; \
		tar xfm linux-${LINUX_VER}.tar && cd linux-${LINUX_VER}; \
	fi
	wget ${USBARMORY_REPO}/software/kernel_conf/${V}/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config
	if test "${V}" = "mark-two"; then \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory.dts; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-tzns.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-tzns.dts; \
	fi
	cd linux-${LINUX_VER} && \
		KBUILD_BUILD_USER=${KBUILD_BUILD_USER} \
		KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} \
		LOCALVERSION=${LOCALVERSION} \
		ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
		make -j${JOBS} zImage modules ${IMX}-usbarmory.dtb ${IMX}-usbarmory-tzns.dtb

#### mxc-scc2 ####

mxc-scc2-master.zip:
	wget ${MXC_SCC2_REPO}/archive/master.zip -O mxc-scc2-master.zip

mxc-scc2-master: mxc-scc2-master.zip
	unzip -o mxc-scc2-master.zip

mxc-scc2-master/mxc-scc2.ko: mxc-scc2-master linux-${LINUX_VER}/arch/arm/boot/zImage
	cd mxc-scc2-master && make KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all

#### mxs-dcp ####

mxs-dcp-master.zip:
	wget ${MXS_DCP_REPO}/archive/master.zip -O mxs-dcp-master.zip

mxs-dcp-master: mxs-dcp-master.zip
	unzip -o mxs-dcp-master.zip

mxs-dcp-master/mxs-dcp.ko: mxs-dcp-master linux-${LINUX_VER}/arch/arm/boot/zImage
	cd mxs-dcp-master && make KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all

#### caam-keyblob ####

caam-keyblob-master.zip:
	wget ${CAAM_KEYBLOB_REPO}/archive/master.zip -O caam-keyblob-master.zip

caam-keyblob-master: caam-keyblob-master.zip
	unzip -o caam-keyblob-master.zip

caam-keyblob-master/caam-keyblob.ko: caam-keyblob-master linux-${LINUX_VER}/arch/arm/boot/zImage
	cd caam-keyblob-master && make KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all

#### dtb ####

extra-dtb: check_version linux-${LINUX_VER}/arch/arm/boot/zImage
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-host.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-host.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-gpio.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-gpio.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-spi.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-spi.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-i2c.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-i2c.dts
	wget ${USBARMORY_REPO}/software/kernel_conf/mark-one/imx53-usbarmory-scc2.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/imx53-usbarmory-scc2.dts
	cd linux-${LINUX_VER} && KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} LOCALVERSION=${LOCALVERSION} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j${JOBS} imx53-usbarmory-host.dtb imx53-usbarmory-gpio.dtb imx53-usbarmory-spi.dtb imx53-usbarmory-i2c.dtb imx53-usbarmory-scc2.dtb

#### linux-image-deb ####

KERNEL_DEPS := check_version
KERNEL_DEPS += linux-${LINUX_VER}/arch/arm/boot/zImage
ifeq ($(V),mark-one)
KERNEL_DEPS += extra-dtb mxc-scc2
endif
ifeq ($(V),mark-two)
KERNEL_DEPS += mxs-dcp caam-keyblob
endif
linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb: $(KERNEL_DEPS)
	mkdir -p linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/{DEBIAN,boot,lib/modules}
	cat control_template_linux | \
		sed -e 's/XXXX/${LINUX_VER_MAJOR}/'          | \
		sed -e 's/YYYY/${LINUX_VER}${LOCALVERSION}/' | \
		sed -e 's/USB armory/USB armory ${V}/' \
		> linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control
	@if test "${V}" = "mark-two"; then \
		sed -i -e 's/${LINUX_VER_MAJOR}-usbarmory/${LINUX_VER_MAJOR}-usbarmory-mark-two/' \
		linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control; \
	fi
	cp -r linux-${LINUX_VER}/arch/arm/boot/zImage linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/zImage-${LINUX_VER}${LOCALVERSION}-usbarmory
	cp -r linux-${LINUX_VER}/.config linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/config-${LINUX_VER}${LOCALVERSION}-usbarmory
	cp -r linux-${LINUX_VER}/System.map linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/System.map-${LINUX_VER}${LOCALVERSION}-usbarmory
	cd linux-${LINUX_VER} && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm modules_install
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb
	@if test "${IMX}" = "imx53"; then \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-host.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-host-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-spi.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-spi-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-gpio.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-gpio-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-i2c.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-i2c-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-scc2.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-scc2-${LINUX_VER}${LOCALVERSION}.dtb; \
		cd mxc-scc2-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	@if test "${IMX}" = "imx6ulz"; then \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-tzns.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-tzns-${LINUX_VER}${LOCALVERSION}.dtb ; \
		KNL_SUM=$(shell sha256sum linux-${LINUX_VER}/arch/arm/boot/zImage | cut -d ' ' -f 1) ; \
		DTB_SUM=$(shell sha256sum linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-tzns.dtb | cut -d ' ' -f 1) ; \
		cat armory-boot.conf.template | \
			sed -e 's/KNL_SUM/'"$${KNL_SUM}"'/' | \
			sed -e 's/DTB_SUM/'"$${DTB_SUM}"'/' | \
			sed -e 's/YYYY/${LINUX_VER}${LOCALVERSION}/' \
			> linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/armory-boot.conf ; \
		cd mxs-dcp-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	@if test "${IMX}" = "imx6ul"; then \
		cd caam-keyblob-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	cd linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf zImage-${LINUX_VER}${LOCALVERSION}-usbarmory zImage
	cd linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf ${IMX}-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb ${IMX}-usbarmory.dtb
	cd linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf ${IMX}-usbarmory.dtb imx6ull-usbarmory.dtb
	rm linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/{build,source}
	chmod 755 linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN
	fakeroot dpkg-deb -b linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb

#### linux-headers-deb ####

HEADER_DEPS := check_version
HEADER_DEPS += linux-${LINUX_VER}/arch/arm/boot/zImage
linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb: $(HEADER_DEPS)
	mkdir -p linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/{DEBIAN,boot,lib/modules/${LINUX_VER}${LOCALVERSION}/build}
	cd linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION} ; ln -sf build source
	cat control_template_linux-headers | \
		sed -e 's/XXXX/${LINUX_VER_MAJOR}/'          | \
		sed -e 's/YYYY/${LINUX_VER}${LOCALVERSION}/' | \
		sed -e 's/ZZZZ/linux-image-${LINUX_VER_MAJOR}-usbarmory (=${LINUX_VER}${LOCALVERSION})/' | \
		sed -e 's/USB armory/USB armory ${V}/' \
		> linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control
	@if test "${V}" = "mark-two"; then \
		sed -i -e 's/${LINUX_VER_MAJOR}-usbarmory/${LINUX_VER_MAJOR}-usbarmory-mark-two/' \
		linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control; \
	fi
	cd linux-${LINUX_VER} && make INSTALL_HDR_PATH=../linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/build ARCH=arm headers_install
	chmod 755 linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN
	fakeroot dpkg-deb -b linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb

#### armoryctl ####

armoryctl-${ARMORYCTL_VER}.zip:
	wget ${ARMORYCTL_REPO}/archive/v${ARMORYCTL_VER}.zip -O armoryctl-v${ARMORYCTL_VER}.zip

armoryctl-${ARMORYCTL_VER}: armoryctl-${ARMORYCTL_VER}.zip
	unzip -o armoryctl-v${ARMORYCTL_VER}.zip

armoryctl-${ARMORYCTL_VER}/armoryctl: armoryctl-${ARMORYCTL_VER}
	cd armoryctl-${ARMORYCTL_VER} && GOPATH=/tmp/go GOARCH=arm BUILD_USER=${BUILD_USER} BUILD_HOST=${BUILD_HOST} make

#### armoryctl-deb ####

armoryctl_${ARMORYCTL_VER}_armhf.deb: armoryctl-${ARMORYCTL_VER}/armoryctl
	mkdir -p armoryctl_${ARMORYCTL_VER}_armhf/{DEBIAN,sbin}
	cat control_template_armoryctl | \
		sed -e 's/YYYY/${ARMORYCTL_VER}/' \
		> armoryctl_${ARMORYCTL_VER}_armhf/DEBIAN/control
	cp -r armoryctl-${ARMORYCTL_VER}/armoryctl armoryctl_${ARMORYCTL_VER}_armhf/sbin
	chmod 755 armoryctl_${ARMORYCTL_VER}_armhf/DEBIAN
	fakeroot dpkg-deb -b armoryctl_${ARMORYCTL_VER}_armhf armoryctl_${ARMORYCTL_VER}_armhf.deb

#### crucible ####

crucible-${CRUCIBLE_VER}.zip:
	wget ${CRUCIBLE_REPO}/archive/v${CRUCIBLE_VER}.zip -O crucible-v${CRUCIBLE_VER}.zip

crucible-${CRUCIBLE_VER}: crucible-${CRUCIBLE_VER}.zip
	unzip -o crucible-v${CRUCIBLE_VER}.zip

crucible-${CRUCIBLE_VER}/crucible: crucible-${CRUCIBLE_VER}
	cd crucible-${CRUCIBLE_VER} && GOPATH=/tmp/go GOARCH=arm BUILD_USER=${BUILD_USER} BUILD_HOST=${BUILD_HOST} make crucible

#### crucible-deb ####

crucible_${CRUCIBLE_VER}_armhf.deb: crucible-${CRUCIBLE_VER}/crucible
	mkdir -p crucible_${CRUCIBLE_VER}_armhf/{DEBIAN,sbin}
	cat control_template_crucible | \
		sed -e 's/YYYY/${CRUCIBLE_VER}/' \
		> crucible_${CRUCIBLE_VER}_armhf/DEBIAN/control
	cp -r crucible-${CRUCIBLE_VER}/crucible crucible_${CRUCIBLE_VER}_armhf/sbin
	chmod 755 crucible_${CRUCIBLE_VER}_armhf/DEBIAN
	fakeroot dpkg-deb -b crucible_${CRUCIBLE_VER}_armhf crucible_${CRUCIBLE_VER}_armhf.deb

#### targets ####

.PHONY: u-boot debian debian-xz linux linux-image-deb linux-headers-deb
.PHONY: mxs-dcp mxc-scc2 caam-keyblob armoryctl armoryctl-deb crucible crucible-deb

u-boot: u-boot-${UBOOT_VER}/u-boot.bin
debian: usbarmory-${IMG_VERSION}.raw
debian-xz: usbarmory-${IMG_VERSION}.raw.xz
linux: linux-${LINUX_VER}/arch/arm/boot/zImage
linux-image-deb: linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
linux-headers-deb: linux-headers-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
mxs-dcp: mxs-dcp-master/mxs-dcp.ko
mxc-scc2: mxc-scc2-master/mxc-scc2.ko
caam-keyblob: caam-keyblob-master/caam-keyblob.ko
armoryctl: armoryctl-${ARMORYCTL_VER}/armoryctl
armoryctl-deb: armoryctl_${ARMORYCTL_VER}_armhf.deb
crucible: crucible-${CRUCIBLE_VER}/crucible
crucible-deb: crucible_${CRUCIBLE_VER}_armhf.deb

release: check_version usbarmory-${IMG_VERSION}.raw.xz
	sha256sum usbarmory-${IMG_VERSION}.raw.xz > usbarmory-${IMG_VERSION}.raw.xz.sha256

clean:
	-rm -fr armoryctl* crucible* linux-* linux-image-* linux-headers-* u-boot-*
	-rm -fr mxc-scc2-master* mxs-dcp-master* caam-keyblob-master*
	-rm -f usbarmory-*.raw
	-sudo umount -f rootfs
	-rmdir rootfs
