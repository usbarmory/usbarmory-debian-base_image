The following instructions illustrate how to prepare the Debian image for the USB armory.

# Prerequisites

Debian 8 with binfmt support and qemu-user-static package.

Add Linux signing gpg key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E
```

Add U-Boot signing gpg key:
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 87F9F635D31D7652
```

# Building

```
make all
```
