FROM debian:10

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod udev cpio

# install golang
ARG GOLANG_TARBALL=go1.13.6.linux-amd64.tar.gz
RUN wget https://dl.google.com/go/$GOLANG_TARBALL
RUN echo a1bc06deb070155c4f67c579f896a45eeda5a8fa54f35ba233304074c4abbbbd $GOLANG_TARBALL | sha256sum -c
RUN tar -C /usr/local -xzf $GOLANG_TARBALL
RUN rm $GOLANG_TARBALL
ENV PATH "$PATH:/usr/local/go/bin"

# import U-Boot signing keys
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E \
    && gpg --keyserver hkp://keys.gnupg.net --recv-keys 147C39FF9634B72C

WORKDIR /opt/armory
