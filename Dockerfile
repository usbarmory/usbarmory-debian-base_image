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
ENV GOLANG_VERSION="1.15.6"
RUN wget -O go.tgz https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz --progress=dot:giga
RUN wget -O go.tgz.asc https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz.asc --progress=dot:giga
RUN echo "3918e6cc85e7eaaa6f859f1bdbaac772e7a825b0eb423c63d3ae68b21f84b844 *go.tgz" | sha256sum --strict --check -
RUN gpg --batch --verify go.tgz.asc go.tgz
RUN tar -C /usr/local -xzf go.tgz && rm go.tgz

ENV PATH "$PATH:/usr/local/go/bin"
ENV GOPATH /go

WORKDIR /opt/armory
