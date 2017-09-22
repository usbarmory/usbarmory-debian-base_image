#!/bin/sh

PREREQ=""

prereqs()
{
    echo "$PREREQ"
}

case $1 in
# get pre-requisites
prereqs)
    prereqs
    exit 0
    ;;
esac

cp $(dpkg -L libc6 | grep libnss_ | tr '\n' ' ') "${DESTDIR}/lib/"
