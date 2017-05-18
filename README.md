The Makefile in this repository is used to generate the Debian image for the USB armory.

# Prerequisites

A Debian 8 machine with the following packages installed is required:

```
bc binfmt-support bzip2 gcc gcc-arm-none-eabi git gnupg make parted qemu-user-static wget xz-utils zip
```

Add Linux signing gpg key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E
```

Add U-Boot signing gpg key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 87F9F635D31D7652
```

# Building

Launch the following command to download and build:

```
make all
```

The following three output files are produced:
```
usbarmory-debian_jessie-base_image-YYYYMMDD.raw
usbarmory-debian_jessie-base_image-YYYYMMDD.raw.xz
usbarmory-debian_jessie-base_image-YYYYMMDD.raw.zip
```
