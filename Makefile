SHELL = /bin/bash
JOBS=2

LINUX_VER=4.19.58
LINUX_VER_MAJOR=${shell echo ${LINUX_VER} | cut -d '.' -f1,2}
LOCALVERSION=-0
UBOOT_VER=2019.04
APT_GPG_KEY=CEADE0CF01939B21

USBARMORY_REPO=https://raw.githubusercontent.com/inversepath/usbarmory/master
MXC_SCC2_REPO=https://github.com/inversepath/mxc-scc2
MXS_DCP_REPO=https://github.com/inversepath/mxs-dcp
CAAM_KEYBLOB_REPO=https://github.com/inversepath/caam-keyblob
IMG_VERSION=${V}-debian_stretch-base_image-$(shell /bin/date -u "+%Y%m%d")

.DEFAULT_GOAL := all

# supported versions: mark-one, mark-two
V ?= mark-two

check_version:
	@if test "${V}" = "mark-one"; then \
		if test "${IMX}" = ""; then \
			echo -n $(eval IMX=imx53 BOOT=uSD); \
		fi; \
		echo "USB armory Mk I target (V=${V} IMX=${IMX} BOOT=${BOOT})"; \
	elif test "${V}" = "mark-two"; then \
		if test "${IMX}" = ""; then \
			echo -n $(eval IMX=imx6ull); \
		fi; \
		if test "${BOOT}" = ""; then \
			echo -n $(eval BOOT=uSD); \
		fi; \
		echo "USB armory Mk II target (V=${V} IMX=${IMX} BOOT=${BOOT})"; \
	else \
		echo "invalid target, set V to mark-one or mark-two"; \
		exit 1; \
	fi

test: check_version
	@echo "(V=${V} IMX=${IMX} BOOT=${BOOT})"

usbarmory-${IMG_VERSION}.raw:
	truncate -s 3500MiB usbarmory-${IMG_VERSION}.raw
	/sbin/parted usbarmory-${IMG_VERSION}.raw --script mklabel msdos
	/sbin/parted usbarmory-${IMG_VERSION}.raw --script mkpart primary ext4 5M 100%

debian: check_version usbarmory-${IMG_VERSION}.raw
	sudo /sbin/losetup /dev/loop0 usbarmory-${IMG_VERSION}.raw -o 5242880 --sizelimit 3500MiB
	sudo /sbin/mkfs.ext4 -F /dev/loop0
	sudo /sbin/losetup -d /dev/loop0
	mkdir -p rootfs
	sudo mount -o loop,offset=5242880 -t ext4 usbarmory-${IMG_VERSION}.raw rootfs/
	sudo qemu-debootstrap \
		--include=ssh,sudo,ntpdate,fake-hwclock,openssl,vim,nano,cryptsetup,lvm2,locales,less,cpufrequtils,isc-dhcp-server,haveged,rng-tools,whois,iw,wpasupplicant,dbus,apt-transport-https,dirmngr,ca-certificates \
		--arch=armhf stretch rootfs http://ftp.debian.org/debian/
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
	@if test "${V}" = "mark-one"; then \
		sudo chroot rootfs systemctl mask rng-tools.service; \
	fi
	@if test "${V}" = "mark-two"; then \
		sudo chroot rootfs systemctl mask haveged.service; \
	fi
	sudo chroot rootfs wget http://keys.inversepath.com/gpg-andrej.asc -O /tmp/gpg-andrej.asc
	sudo chroot rootfs wget http://keys.inversepath.com/gpg-andrea.asc -O /tmp/gpg-andrea.asc
	sudo chroot rootfs apt-key add /tmp/gpg-andrej.asc
	sudo chroot rootfs apt-key add /tmp/gpg-andrea.asc
	echo "ledtrig_heartbeat" | sudo tee -a rootfs/etc/modules
	echo "ci_hdrc_imx" | sudo tee -a rootfs/etc/modules
	echo "g_ether" | sudo tee -a rootfs/etc/modules
	echo -e 'auto usb0\nallow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2'| sudo tee -a rootfs/etc/network/interfaces
	echo "usbarmory" | sudo tee rootfs/etc/hostname
	echo "usbarmory  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a rootfs/etc/sudoers
	echo -e "127.0.1.1\tusbarmory" | sudo tee -a rootfs/etc/hosts
	sudo chroot rootfs /usr/sbin/useradd -s /bin/bash -p `sudo chroot rootfs mkpasswd -m sha-512 usbarmory` -m usbarmory
	sudo rm rootfs/etc/ssh/ssh_host_*
	sudo cp linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb rootfs/tmp/
	sudo chroot rootfs /usr/bin/dpkg -i /tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
	sudo rm rootfs/tmp/linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb
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
	@if [ ! -d "linux-${LINUX_VER}" ]; then \
		unxz --keep linux-${LINUX_VER}.tar.xz; \
		gpg --verify linux-${LINUX_VER}.tar.sign; \
		tar xvf linux-${LINUX_VER}.tar && cd linux-${LINUX_VER}; \
	fi
	wget ${USBARMORY_REPO}/software/kernel_conf/${V}/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config
	if test "${V}" = "mark-two"; then \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory.dts; \
	fi
	cd linux-${LINUX_VER} && KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory LOCALVERSION=${LOCALVERSION} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j${JOBS} zImage modules ${IMX}-usbarmory.dtb

u-boot-${UBOOT_VER}/u-boot.imx: u-boot-${UBOOT_VER}.tar.bz2
	gpg --verify u-boot-${UBOOT_VER}.tar.bz2.sig
	tar xvf u-boot-${UBOOT_VER}.tar.bz2
	cd u-boot-${UBOOT_VER} && make distclean
	@if test "${V}" = "mark-one"; then \
		cd u-boot-${UBOOT_VER} && make usbarmory_config; \
	elif test "${V}" = "mark-two"; then \
		cd u-boot-${UBOOT_VER} && \
		wget ${USBARMORY_REPO}/software/u-boot/0001-USB-armory-mark-two-alpha-${BOOT}.patch && \
		patch -p1 < 0001-USB-armory-mark-two-alpha-${BOOT}.patch && \
		make usbarmory-mark-two_defconfig; \
	fi
	cd u-boot-${UBOOT_VER} && CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm make -j${JOBS}

mxc-scc2-master.zip:
	@if test "${IMX}" = "imx53"; then \
		wget ${MXC_SCC2_REPO}/archive/master.zip -O mxc-scc2-master.zip && \
		unzip mxc-scc2-master; \
	fi

mxs-dcp-longterm.zip:
	@if test "${IMX}" = "imx6ull"; then \
		wget ${MXS_DCP_REPO}/archive/longterm.zip -O mxs-dcp-longterm.zip && \
		unzip mxs-dcp-longterm; \
	fi

caam-keyblob-master.zip:
	@if test "${IMX}" = "imx6ul"; then \
		wget ${CAAM_KEYBLOB_REPO}/archive/master.zip -O caam-keyblob-master.zip && \
		unzip caam-keyblob-master; \
	fi

linux: linux-${LINUX_VER}/arch/arm/boot/zImage

mxc-scc2: mxc-scc2-master.zip linux
	@if test "${IMX}" = "imx53"; then \
		cd mxc-scc2-master && make KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all; \
	fi

mxs-dcp: mxs-dcp-longterm.zip linux
	@if test "${IMX}" = "imx6ull"; then \
		cd mxs-dcp-longterm && make KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all; \
	fi

caam-keyblob: caam-keyblob-master.zip linux
	@if test "${IMX}" = "imx6ul"; then \
		cd caam-keyblob-master && make KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all; \
	fi

extra-dtb: check_version linux
	@if test "${V}" = "mark-one"; then \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/usbarmory_linux-${LINUX_VER_MAJOR}.config -O linux-${LINUX_VER}/.config; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-host.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-host.dts; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-gpio.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-gpio.dts; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-spi.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-spi.dts; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-i2c.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-i2c.dts; \
		wget ${USBARMORY_REPO}/software/kernel_conf/${V}/${IMX}-usbarmory-scc2.dts -O linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-scc2.dts; \
		cd linux-${LINUX_VER} && KBUILD_BUILD_USER=usbarmory KBUILD_BUILD_HOST=usbarmory LOCALVERSION=${LOCALVERSION} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j${JOBS} ${IMX}-usbarmory-host.dtb ${IMX}-usbarmory-gpio.dtb ${IMX}-usbarmory-spi.dtb ${IMX}-usbarmory-i2c.dtb ${IMX}-usbarmory-scc2.dtb; \
	fi

linux-deb: check_version linux extra-dtb mxc-scc2 mxs-dcp caam-keyblob
	mkdir -p linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/{DEBIAN,boot,lib/modules}
	cat control_template | \
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
		cd mxc-scc2-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-host.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-host-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-spi.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-spi-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-gpio.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-gpio-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-i2c.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-i2c-${LINUX_VER}${LOCALVERSION}.dtb; \
		cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory-scc2.dtb linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-scc2-${LINUX_VER}${LOCALVERSION}.dtb; \
	fi
	@if test "${IMX}" = "imx6ull"; then \
		cd mxs-dcp-longterm && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	@if test "${IMX}" = "imx6ul"; then \
		cd caam-keyblob-master && make INSTALL_MOD_PATH=../linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	cd linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -s zImage-${LINUX_VER}${LOCALVERSION}-usbarmory zImage
	cd linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -s ${IMX}-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb ${IMX}-usbarmory.dtb
	rm linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/{build,source}
	fakeroot dpkg-deb -b linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf.deb

u-boot: u-boot-${UBOOT_VER}/u-boot.imx

finalize: usbarmory-${IMG_VERSION}.raw u-boot-${UBOOT_VER}/u-boot.imx
	sudo dd if=u-boot-${UBOOT_VER}/u-boot.imx of=usbarmory-${IMG_VERSION}.raw bs=512 seek=2 conv=fsync conv=notrunc

compress:
	xz -k usbarmory-${IMG_VERSION}.raw
	zip -j usbarmory-${IMG_VERSION}.raw.zip usbarmory-${IMG_VERSION}.raw

all: check_version linux-deb debian u-boot finalize

clean:
	-rm -fr linux-${LINUX_VER}*
	-rm -fr u-boot-${UBOOT_VER}*
	-rm -fr linux-image-${LINUX_VER_MAJOR}-usbarmory-${V}_${LINUX_VER}${LOCALVERSION}_armhf*
	-rm -fr mxc-scc2-master* mxs-dcp-longterm* caam-keyblob-master*
	-rm -f usbarmory-${V}-debian_stretch-base_image-*.raw
	-rmdir rootfs
