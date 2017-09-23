The Makefile in this repository allows generation of a basic Debian / Devuan
installation for the [USB armory](https://github.com/inversepath/usbarmory).

Pre-compiled releases are [available](https://github.com/inversepath/usbarmory-debian-base_image/releases).

# Prerequisites

A Debian / Devuan 8 installation with the following packages for Makefile.Debian:

```
bc binfmt-support bzip2 gcc gcc-arm-none-eabi git gnupg make parted qemu-user-static wget xz-utils zip
```

or the following packages for Makefile.Devuan:
```
bc binfmt-support bzip2 gcc gcc-arm-none-eabi git gnupg kpartx make parted pv qemu-user-static wget xz-utils zip
```

Import the Linux signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E
```

Import the U-Boot signing GPG key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 87F9F635D31D7652
```
Copy or link either Makefile.Debian or Makefile.Devuan to Makefile.
(or use `make -f <filename>` whenever make is mentioned below)

With Makefile.Devuan you will prepare a 4 GB image where the first partition
is unencrypted for boot files and the second partition is encrypted with LUKS
and has LVM inside to provide maximum flexibility.  Since the /boot partition
(/dev/mmcblk0p1) is not encrypted it will not protect against [Evil Maid
attack](https://en.wikipedia.org/wiki/Rootkit#bootkit) but the small
size/portability of the USB Armory should help to weaken this attack vector.
(Secure Boot is deprecated due to
a [possible bypass](https://github.com/inversepath/usbarmory/blob/master/software/secure_boot/Security_Advisory-Ref_QBVR2017-0001.txt)
on the used chip)

# Building

Launch the following command to download and build the image:

```
make all
```

The following output files are produced:
```
usbarmory-de{bi,vu}an_jessie-base_image-YYYYMMDD.raw
usbarmory-de{bi,vu}an_jessie-base_image-YYYYMMDD.raw.xz
usbarmory-de{bi,vu}an_jessie-base_image-YYYYMMDD.raw.zip
```

For Makefile.Devuan additionally the following file is produced:
```
luks.keyfile
```
which holds a 4096 bit random key to unlock the LUKS partition that
was created.

If you used `make all` or `make safe-devuan` you will have been
prompted for a passphrase for the LUKS partition and the LUKS keyslot
for the keyfile will have been removed.
Otherwise, please make sure that a passphrase for the LUKS encrypted
partition is set, e.g. using `make lukspw` (otherwise you would need to
type the contents of the keyfile at boot time into the ssh console
to unlock the partition, which might prove difficult or maybe
even impossible if some special characters are included that would interfere
with normal ssh operation (e.g. "<newline>~." could be interpreted to close
the connection by ssh and therefore leave you no way to proceed)) and to
remove the keyfile from the LUKS keyslot (e.g. `make luksrmkeyfileslot`)
as well as securely delete the luks.keyfile file.

Please note that the `luks.keyfile` keyfile will never be removed
automatically to avoid locking you out and having to start over from
scratch. You will have to securely wipe it yourself once it is not needed 
anymore, e.g. by using `shred`:
```
shred -u luks.keyfile
```


# Installing

**IMPORTANT**: `/dev/sdX`, `/dev/diskN` must be replaced with your microSD
device (not eventual microSD partitions), ensure that you are specifying the
correct one. Errors in target specification will result in disk corruption.

Linux (verify target from terminal using `dmesg`):
```
sudo dd if=usbarmory-debian_jessie-base_image-YYYYMMDD.raw of=/dev/sdX bs=1M conv=fsync
#or
sudo dd if=usbarmory-devuan_jessie-base_image-YYYYMMDD.raw of=/dev/sdX bs=1M conv=fsync
```

Mac OS X (verify target from terminal with `diskutil list`):
```
sudo dd if=usbarmory-debian_jessie-base_image-YYYYMMDD.raw of=/dev/rdiskN bs=1m
#or
sudo dd if=usbarmory-devuan_jessie-base_image-YYYYMMDD.raw of=/dev/rdiskN bs=1m
```

On Windows, and other OSes, alternatively the [Etcher](https://etcher.io)
utility can be used.

# Connecting

For a Devuan image (i.e. using Makefile.Devuan) you will need to, during early boot,
(while the LED is still dimly lit), ssh in (see also next paragraph) to
unlock the LUKS partition. You can do so with
```
ssh unlock@10.0.0.1   # password "unlock" without quotes
```
and you will be asked automatically to provide the passphrase.
Kindly note that the unlocking might take considerably longer time than on your PC
(e.g. 30-40 seconds instead of a (few) second(s); depending on your PC hardware)
which is completely normal and expected and is due to the LUKS partition having
been created on your PC.
If the calibration would be reduced to make it faster on the USB Armory it would
lead to being that much easier to crack in a brute force attack on commodity
hardware similar to your PC. If you really, really want/need to change it
you can read up on the --iter-time option for cryptsetup.

After being booted, the image uses Ethernet over USB emulation (CDC Ethernet)
to communicate with the host, with assigned IP address 10.0.0.1 (using 10.0.0.2
as gateway). Connection can be accomplished via SSH to 10.0.0.1, with default
user `usbarmory` and password `usbarmory`. NOTE: There is a DHCP server running
by default. Alternatively the host interface IP address can be statically set
to 10.0.0.2/24.

# LED feedback

To aid initial testing the base image configures the board LED to reflect CPU
load average, via the Linux Heartbeat Trigger driver. In case this is
undesired, the heartbeat can be disabled by removing the `ledtrig_heartbeat`
module in `/etc/modules`. More information about LED control
[here](https://github.com/inversepath/usbarmory/wiki/GPIOs#led-control).

# Resizing

The default image is 4GB of size, to use the full microSD space a new partition
can be added or the existing one can be resized as described in the USB armory
[FAQ](https://github.com/inversepath/usbarmory/wiki/Frequently-Asked-Questions-(FAQ)).

# Additional resources

[Project page](https://inversepath.com/usbarmory)  
[Documentation](https://github.com/inversepath/usbarmory/wiki)  
[Board schematics, layout and support files](https://github.com/inversepath/usbarmory)  
[INTERLOCK - file encryption front end](https://github.com/inversepath/interlock)  
[Discussion group](https://groups.google.com/d/forum/usbarmory)  

# License

The files in this repository are in the public domain.
See the file LICENSE for details.
