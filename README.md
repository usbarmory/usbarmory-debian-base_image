# USB armory Debian base image [![Build Status](https://github.com/usbarmory/usbarmory-debian-base_image/workflows/Build-All/badge.svg)](https://github.com/usbarmory/usbarmory-debian-base_image/actions)

The Makefile in this repository allows generation of a basic Debian
installation for the [USB armory](https://github.com/usbarmory/usbarmory).

Pre-compiled releases are [available](https://github.com/usbarmory/usbarmory-debian-base_image/releases).

## Pre-requisites

A Debian 9 installation with the following packages:

```
bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf git
gnupg make parted rsync qemu-user-static wget xz-utils zip debootstrap
sudo dirmngr bison flex libssl-dev kmod
```

Follow [Go installation instructions](https://go.dev/doc/install) to
install the last available Go version.

Import the Linux signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E
```

Import the U-Boot signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 147C39FF9634B72C
```

The `loop` Linux kernel module must be enabled/loaded, also mind that the
Makefile relies on the ability to execute privileged commands via `sudo`.

## Docker pre-requisites

When building the image under Docker the `--privileged` option is required to
give privileges for handling loop devices, example:

```
docker build --rm --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t armory ./
docker run --rm -it --privileged -v $(pwd):/usbarmory --name armory armory
```

On Mac OS X the build needs to be done in a case-sensitive filesystem. Such
filesystem can be created with `Disk Utility` by selecting `File > New Image >
Blank Image`, choosing `Size: 5GB` and `Format: APFS (Case-sensitive)`. Double
click on the created dmg file to mount it.

## Building

Launch the following command to download and build the image:

```
# For the USB armory Mk II (external microSD)
make V=mark-two IMX=imx6ulz BOOT=uSD

# For the USB armory Mk II (internal eMMC)
make V=mark-two IMX=imx6ulz BOOT=eMMC

# For the USB armory Mk I
make V=mark-one IMX=imx53
```

The following output files are produced:

```
# For the USB armory Mk II
usbarmory-mark-two-debian_bookworm-base_image-YYYYMMDD.raw

# For the USB armory Mk I
usbarmory-mark-one-debian_bookworm-base_image-YYYYMMDD.raw
```

## Installation

**WARNING**: the following operations will destroy any previous contents on the
external microSD or internal eMMC storage.

**IMPORTANT**: `/dev/sdX`, `/dev/diskN` must be replaced with your microSD or
eMMC device (not eventual partitions), ensure that you are specifying the
correct one. Errors in target specification will result in disk corruption.

Linux (verify target from terminal using `dmesg`):
```
sudo dd if=usbarmory-*-debian_bookworm-base_image-YYYYMMDD.raw of=/dev/sdX bs=1M conv=fsync
```

Mac OS X (verify target from terminal with `diskutil list`):
```
sudo dd if=usbarmory-*-debian_bookworm-base_image-YYYYMMDD.raw of=/dev/rdiskN bs=1m
```

On Windows, and other OSes, alternatively the [Etcher](https://etcher.io)
utility can be used.

### Accessing the USB armory Mk II internal eMMC as USB storage device

Set the USB armory Mk II to boot in Serial Boot Loader by setting the boot
switch towards the microSD slot, without a microSD card connected. Connect the
USB Type-C interface to the host and verify that your host kernel successfully
detects the board:

```
usb 1-1: new high-speed USB device number 8 using xhci_hcd
usb 1-1: New USB device found, idVendor=15a2, idProduct=0080, bcdDevice= 0.01
usb 1-1: New USB device strings: Mfr=1, Product=2, SerialNumber=0
usb 1-1: Product: SE Blank 6ULL
usb 1-1: Manufacturer: Freescale SemiConductor Inc 
hid-generic 0003:15A2:0080.0003: hiddev96,hidraw1: USB HID v1.10 Device [Freescale SemiConductor Inc  SE Blank 6ULL] on usb-0000:00:14.0-1/input0
```

Load the [armory-ums](https://github.com/usbarmory/armory-ums/releases)
firmware using the [armory-boot-usb](https://github.com/usbarmory/armory-boot/tree/master/cmd/armory-boot-usb) utility:

```
sudo armory-boot-usb -i armory-ums.imx
```

Once loaded, the host kernel should detect a USB storage device, corresponding
to the internal eMMC.

## Connecting

After being booted, the image uses Ethernet over USB emulation (CDC Ethernet)
to communicate with the host, with assigned IP address 10.10.10.1 (using 10.10.10.2
as gateway). Connection can be accomplished via SSH to 10.10.10.1, with default
user `usbarmory` and password `usbarmory`. NOTE: There is a DHCP server running
by default. Alternatively the host interface IP address can be statically set
to 10.10.10.2/24.

## LED feedback

To aid initial testing the base image configures the board LED to reflect CPU
load average, via the Linux Heartbeat Trigger driver. In case this is
undesired, the heartbeat can be disabled by removing the `ledtrig_heartbeat`
module in `/etc/modules`. More information about LED control
[here](https://github.com/usbarmory/usbarmory/wiki/GPIOs#led-control).

## Resizing

The default image is 4GB of size, to use the full microSD/eMMC space a new partition
can be added or the existing one can be resized as described in the USB armory
[FAQ](https://github.com/usbarmory/usbarmory/wiki/Frequently-Asked-Questions-(FAQ)).

## Additional resources

[Project page](https://github.com/usbarmory/usbarmory)  
[Documentation](https://github.com/usbarmory/usbarmory/wiki)  
[Board schematics, layout and support files](https://github.com/usbarmory/usbarmory)  
[Discussion group](https://groups.google.com/d/forum/usbarmory)  
