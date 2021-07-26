FROM debian:10

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted rsync qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod udev cpio

# import U-Boot signing keys
RUN gpg --batch --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys 38DBBDC86092693E && \
    gpg --batch --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys 147C39FF9634B72C && \
# import golang signing keys
    gpg --batch --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys 7721F63BD38B4796

# install golang
ENV GOLANG_VERSION="1.16.6"
RUN wget -O go.tgz https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz --progress=dot:giga
RUN wget -O go.tgz.asc https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz.asc --progress=dot:giga
RUN echo "be333ef18b3016e9d7cb7b1ff1fdb0cac800ca0be4cf2290fe613b3d069dfe0d *go.tgz" | sha256sum --strict --check -
RUN gpg --batch --verify go.tgz.asc go.tgz
RUN tar -C /usr/local -xzf go.tgz && rm go.tgz

ENV PATH "$PATH:/usr/local/go/bin"
ENV GOPATH /go

WORKDIR /opt/armory
