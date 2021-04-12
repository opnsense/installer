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
usr/local
usr/obj
usr/sbin
usr/share
usr/src
var
"

ALL=0

CPDUP_CUR=0
CPDUP_MAX=$(echo "${ITEMS}" | wc -l)
CPDUP_TXT="Cloning current system"
CPDUP=0

MTREE_TXT="Verifying target system"
MTREE=0

: > /var/log/installer.log

for ITEM in ${ITEMS}; do
	CPDUP=$((CPDUP_CUR * 100))
	CPDUP=$((CPDUP / CPDUP_MAX))
	ALL=$((CPDUP * 80))
	ALL=$((ALL / 100))
	if [ -e /${ITEM} ]; then
		dialog --backtitle "HardenedBSD Installer" \
		    --title "Installation Progress" "${@}" \
		    --mixedgauge "" 0 0 ${ALL} \
		    "${CPDUP_TXT}" "-${CPDUP}" \
		    "${MTREE_TXT}" "-${MTREE}"
		if [ -d /${ITEM} ]; then
			mkdir -p ${BSDINSTALL_CHROOT}/${ITEM} 2>&1
		fi
		# XXX raise error
		(cpdup -v /${ITEM} ${BSDINSTALL_CHROOT}/${ITEM} 2>&1) >> /var/log/installer.log
	fi
	CPDUP_CUR=$((CPDUP_CUR + 1))
done

CPDUP=100
ALL=80

dialog --backtitle "HardenedBSD Installer" \
    --title "Installation Progress" "${@}" \
    --mixedgauge "" 0 0 ${ALL} \
    "${CPDUP_TXT}" "-${CPDUP}" \
    "${MTREE_TXT}" "-${MTREE}"

if [ -f /etc/installed_filesystem.mtree ]; then
	# XXX raise error
	mtree -U -e -q -f /etc/installed_filesystem.mtree -p ${BSDINSTALL_CHROOT} >> /var/log/installer.log
	rm ${BSDINSTALL_CHROOT}/etc/installed_filesystem.mtree
fi

MTREE=100
ALL=90

dialog --backtitle "HardenedBSD Installer" \
    --title "Installation Progress" "${@}" \
    --mixedgauge "" 0 0 ${ALL} \
    "${CPDUP_TXT}" "-${CPDUP}" \
    "${MTREE_TXT}" "-${MTREE}"

sync

mount -t devfs devfs ${BSDINSTALL_CHROOT}/dev
chroot ${BSDINSTALL_CHROOT} /bin/sh /etc/rc.d/ldconfig start

ALL=100

dialog --backtitle "HardenedBSD Installer" \
    --title "Installation Progress" "${@}" \
    --mixedgauge "" 0 0 ${ALL} \
    "${CPDUP_TXT}" "-${CPDUP}" \
    "${MTREE_TXT}" "-${MTREE}"
