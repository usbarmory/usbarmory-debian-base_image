FROM debian:9

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod

RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E \
    && gpg --keyserver hkp://keys.gnupg.net --recv-keys 87F9F635D31D7652

WORKDIR /opt/armory