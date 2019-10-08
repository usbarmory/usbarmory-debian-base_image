# USB armory Debian base image

The Makefile in this repository allows generation of a basic Debian
installation for the [USB armory](https://github.com/inversepath/usbarmory).

Pre-compiled releases are [available](https://github.com/inversepath/usbarmory-debian-base_image/releases).

## Pre-requisites

A Debian 9 installation with the following packages:

```
bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf git gnupg make parted qemu-user-static wget xz-utils zip debootstrap sudo dirmngr bison flex libssl-dev kmod
```

Import the Linux signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E
```

Import the U-Boot signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 87F9F635D31D7652
```

## Docker pre-requisites

When building the image under Docker the `--privileged` option is required to
give privileges for handling loop devices, example:

```
docker build --rm -t armory ./
docker run -it --privileged -v $(pwd):/opt/armory --name armory armory
```

## Building

Launch the following command to download and build the image:

```
# For the USB armory Mk II (external microSD)
make all V=mark-two IMX=imx6ull BOOT=uSD

# For the USB armory Mk II (internal eMMC)
make all V=mark-two IMX=imx6ull BOOT=eMMC

# For the USB armory Mk I
make all V=mark-one IMX=imx53
```

The following output files are produced:

```
# For the USB armory Mk II
usbarmory-mark-two-debian_stretch-base_image-YYYYMMDD.raw

# For the USB armory Mk I
usbarmory-mark-one-debian_stretch-base_image-YYYYMMDD.raw
```

## Installation

**WARNING**: the following operations will destroy any previous contents on the
external microSD or internal eMMC storage.

**IMPORTANT**: `/dev/sdX`, `/dev/diskN` must be replaced with your microSD or
eMMC device (not eventual partitions), ensure that you are specifying the
correct one. Errors in target specification will result in disk corruption.

Linux (verify target from terminal using `dmesg`):
```
sudo dd if=usbarmory-*-debian_stretch-base_image-YYYYMMDD.raw of=/dev/sdX bs=1M conv=fsync
```

Mac OS X (verify target from terminal with `diskutil list`):
```
sudo dd if=usbarmory-*-debian_stretch-base_image-YYYYMMDD.raw of=/dev/rdiskN bs=1m
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

Load the bootloader using the [imx_loader](https://github.com/boundarydevices/imx_usb_loader) utility:

```
imx_usb u-boot-20*.*/u-boot-dtb.imx
```

On the USB armory Mk II serial console, accessible through the
[debug accessory](https://github.com/inversepath/usbarmory/tree/master/hardware/mark-two-debug-accessory),
start the USB storage emulation (UMS) mode:

```
=> ums 0 mmc 1
```

Alternatively, if external serial console access is not available, a
[patch](https://github.com/inversepath/usbarmory/tree/master/software/u-boot/0001-USB-armory-mark-two-alpha-UMS.patch)
to automatically enable UMS mode can be applied to U-Boot 2019.04.

Once in UMS mode, the host kernel should detect a USB storage device:

```
scsi 3:0:0:0: Direct-Access     Linux    UMS disk 0       ffff PQ: 0 ANSI: 2
sd 3:0:0:0: [sdX] 7471104 512-byte logical blocks: (3.83 GB/3.56 GiB)
sd 3:0:0:0: [sdX] Write Protect is off
sd 3:0:0:0: [sdX] Mode Sense: 0f 00 00 00
sd 3:0:0:0: [sdX] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
 sdX: sdX1 sdX2
sd 3:0:0:0: [sdX] Attached SCSI removable disk
```

## Connecting

After being booted, the image uses Ethernet over USB emulation (CDC Ethernet)
to communicate with the host, with assigned IP address 10.0.0.1 (using 10.0.0.2
as gateway). Connection can be accomplished via SSH to 10.0.0.1, with default
user `usbarmory` and password `usbarmory`. NOTE: There is a DHCP server running
by default. Alternatively the host interface IP address can be statically set
to 10.0.0.2/24.

## LED feedback

To aid initial testing the base image configures the board LED to reflect CPU
load average, via the Linux Heartbeat Trigger driver. In case this is
undesired, the heartbeat can be disabled by removing the `ledtrig_heartbeat`
module in `/etc/modules`. More information about LED control
[here](https://github.com/inversepath/usbarmory/wiki/GPIOs#led-control).

## Resizing

The default image is 4GB of size, to use the full microSD/eMMC space a new partition
can be added or the existing one can be resized as described in the USB armory
[FAQ](https://github.com/inversepath/usbarmory/wiki/Frequently-Asked-Questions-(FAQ)).

## Additional resources

[Project page](https://inversepath.com/usbarmory)  
[Documentation](https://github.com/inversepath/usbarmory/wiki)  
[Board schematics, layout and support files](https://github.com/inversepath/usbarmory)  
[INTERLOCK - file encryption front end](https://github.com/inversepath/interlock)  
[Discussion group](https://groups.google.com/d/forum/usbarmory)  
