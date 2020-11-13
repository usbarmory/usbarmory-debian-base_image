FROM debian:10

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod udev cpio

# install golang
ARG GOLANG_VERSION="1.15.3"
ARG GOLANG_TARBALL=go${GOLANG_VERSION}.linux-amd64.tar.gz
RUN wget https://storage.googleapis.com/golang/$GOLANG_TARBALL --progress=dot:giga
RUN echo 010a88df924a81ec21b293b5da8f9b11c176d27c0ee3962dc1738d2352d3c02d $GOLANG_TARBALL | sha256sum -c
RUN tar -C /usr/local -xzf $GOLANG_TARBALL
RUN rm $GOLANG_TARBALL
ENV PATH "$PATH:/usr/local/go/bin"

# import U-Boot signing keys
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 38DBBDC86092693E \
    && gpg --keyserver hkp://keys.gnupg.net --recv-keys 147C39FF9634B72C

WORKDIR /opt/armory
