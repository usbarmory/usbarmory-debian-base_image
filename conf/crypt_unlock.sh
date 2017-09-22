#!/bin/sh

PREREQ="dropbear"

prereqs() {
    echo "$PREREQ"
}

case "$1" in
    prereqs)
        prereqs
        exit 0
    ;;
esac

. "${CONFDIR}/initramfs.conf"
. /usr/share/initramfs-tools/hook-functions

if [ "${DROPBEAR}" != "n" ] && [ -r "/etc/crypttab" ] ; then
    cat > "${DESTDIR}/bin/unlock" << EOF
#!/bin/sh
if PATH=/lib/unlock:/bin:/sbin /scripts/local-top/cryptroot; then
    kill \`ps | grep cryptroot | grep -v grep | awk '{print \$1}'\`
    exit 0
fi
exit 1
EOF

    chmod 755 "${DESTDIR}/bin/unlock"

    # Password for a root user named "unlock" is set to "unlock". You can generate one yourself using `mkpasswd -m sha-512`.
    # Don't forget to escape the $ in the here document!
    # To verify the one below, use `echo unlock | mkpasswd -m sha-512 -S "RoSZOXvzXPbNKQtR"`.
    # The login shell is set to /bin/unlock which we created above. (it needs to be in /etc/shells for dropbear to let us in,
    # which we handle below)
    cat > "${DESTDIR}/etc/passwd" << EOF
unlock:\$5\$RoSZOXvzXPbNKQtR\$HoAy8gstVWV5.dDnBRCTQbmQ.PvgkNmrNYW.oXJMET0:0:0:root:/root:/bin/unlock
EOF
    cat > "${DESTDIR}/etc/shells" << EOF
/bin/unlock
EOF

fi
