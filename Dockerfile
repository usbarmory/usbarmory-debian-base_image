FROM ubuntu:22.04

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    bc binfmt-support bzip2 fakeroot file gcc gcc-arm-linux-gnueabihf \
    git gnupg make parted rsync qemu-user-static wget xz-utils zip \
    debootstrap sudo dirmngr bison flex libssl-dev kmod udev cpio \
    apt-utils

# create user "builder" with sudo privileges
ARG GID
ARG UID
ARG USER=builder
RUN groupadd --gid ${GID} $USER
RUN useradd --uid ${UID} --gid $USER --shell /bin/bash --home-dir /home/$USER --create-home $USER
RUN echo "builder ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

# import U-Boot signing keys
RUN su - $USER -c "gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 38DBBDC86092693E"
RUN su - $USER -c "gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 147C39FF9634B72C"
# import golang signing keys
RUN su - $USER -c "gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 7721F63BD38B4796"

# install golang
ENV GOLANG_VERSION="1.22.1"

RUN su - $USER -c "wget -O go.tgz https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz"
RUN su - $USER -c "wget -O go.tgz.asc https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz.asc"
RUN su - $USER -c "gpg --batch --verify go.tgz.asc go.tgz"
RUN tar -C /usr/local -xzf /home/$USER/go.tgz && rm /home/$USER/go.tgz*

ENV PATH "$PATH:/usr/local/go/bin"
ENV GOPATH "/home/${USER}/go"

USER $USER
WORKDIR /usbarmory
