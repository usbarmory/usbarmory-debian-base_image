FROM debian:20.04

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted rsync qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod udev cpio

# import U-Boot signing keys
RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 38DBBDC86092693E && \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 147C39FF9634B72C && \
# import golang signing keys
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 7721F63BD38B4796

# install golang
ENV GOLANG_VERSION="1.17.8"

RUN wget -O go.tgz https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz --progress=dot:giga
RUN wget -O go.tgz.asc https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz.asc --progress=dot:giga
RUN gpg --batch --verify go.tgz.asc go.tgz
RUN tar -C /usr/local -xzf go.tgz && rm go.tgz

ENV PATH "$PATH:/usr/local/go/bin"
ENV GOPATH /go

WORKDIR /opt/armory
