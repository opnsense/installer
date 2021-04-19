#!/bin/sh
#-
# Copyright (c) 2021 Franco Fichtner <franco@opnsense.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

LOGFILE="/var/log/installer.log"
LOGTEMP="/tmp/installer.log"

: > ${LOGFILE}

if mount | awk '{ print $3 }' | grep -qx ${BSDINSTALL_CHROOT}/dev; then
	(umount ${BSDINSTALL_CHROOT}/dev 2>&1) >> ${LOGFILE}
fi

fatal()
{
	# reverse log to show abort reason on top
	tail -r ${LOGFILE} > ${LOGTEMP}

	dialog --clear --backtitle "OPNsense Installer" \
	    --title "Installation Error" --textbox ${LOGTEMP} 22 77

	dialog --backtitle "OPNsense Installer" --title "Installation Abort" \
	    --no-label "Abort" --yes-label "Continue" --yesno \
	    "An installation error occurred. Would you like to attempt to continue the installation anyway?" 0 0

	if [ $? -ne 0 ]; then
		exit 1
	fi
}

progress()
{
	dialog --backtitle "OPNsense Installer" \
	    --title "Installation Progress" "${@}" \
	    --mixedgauge "" 0 0 ${ALL} \
	    "Cloning current system"    "-${CPDUP}" \
	    "Verifying resulting files" "-${MTREE}" \
	    "Preparing target system"   "-${BOOT}"
}

ITEMS="
.cshrc
.profile
COPYRIGHT
bin
boot
boot.config
conf
dev
etc
home
lib
libexec
media
proc
rescue
root
sbin
sys
usr/bin
usr/games
usr/include
usr/lib
usr/lib32
usr/libdata
usr/libexec
%%usr/local%%
usr/obj
usr/sbin
usr/share
usr/src
var
"

# expand usr/local so we can measure more accurate progress
ITEMS=$(for ITEM in ${ITEMS}; do
	if [ "${ITEM}" = "%%usr/local%%" ]; then
		ITEM=$(find /usr/local -d 2 | sed 's/^\///')
	fi
	echo "${ITEM}"
done)

for USRDIR in $(find /usr/local -d 1 -type d); do
	(mkdir -p ${BSDINSTALL_CHROOT}/${USRDIR} 2>&1) >> ${LOGFILE}
done

ALL=0
BOOT=0
CPDUP=0
CPDUP_CUR=0
CPDUP_MAX=$(echo "${ITEMS}" | wc -l)
MTREE=0

progress "${@}"

for ITEM in ${ITEMS}; do
	CPDUP_LAST=${CPDUP}

	CPDUP=$((CPDUP_CUR * 100))
	CPDUP=$((CPDUP / CPDUP_MAX))

	ALL=$((CPDUP * 80))
	ALL=$((ALL / 100))

	CPDUP_CUR=$((CPDUP_CUR + 1))

	if [ "${CPDUP}" != "${CPDUP_LAST}" ]; then
		progress "${@}"
	fi

	if [ -e /${ITEM} -o -L /${ITEM} ]; then
		if ! (cpdup -i0 -o -s0 -v /${ITEM} ${BSDINSTALL_CHROOT}/${ITEM} 2>&1) >> ${LOGFILE}; then
			fatal
		fi
	fi
done

CPDUP=100
ALL=80

progress "${@}"

if [ -f /etc/installed_filesystem.mtree ]; then
	rm ${BSDINSTALL_CHROOT}/etc/installed_filesystem.mtree
	if ! (mtree -U -e -q -f /etc/installed_filesystem.mtree -p ${BSDINSTALL_CHROOT} 2>&1) >> ${LOGFILE}; then
		fatal
	fi
fi

MTREE=100
ALL=90

progress "${@}"

cp ${LOGFILE} ${BSDINSTALL_CHROOT}${LOGFILE}

sync

(mount -t devfs devfs ${BSDINSTALL_CHROOT}/dev 2>&1) >> ${LOGFILE}
(chroot ${BSDINSTALL_CHROOT} /bin/sh /etc/rc.d/ldconfig start 2>&1) >> ${LOGFILE}

cp ${BSDINSTALL_TMPETC}/fstab ${BSDINSTALL_CHROOT}/etc

mkdir -p ${BSDINSTALL_CHROOT}/tmp
chmod 1777 ${BSDINSTALL_CHROOT}/tmp

# /boot/loader.conf et al
(chroot ${BSDINSTALL_CHROOT} /usr/local/sbin/pluginctl -s login restart 2>&1) >> ${LOGFILE}

ALL=100
BOOT=100

progress "${@}"
