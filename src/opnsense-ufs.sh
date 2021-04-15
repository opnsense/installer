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

DEVICES=$(find /dev -d 1 \! -type d)
DISKS=

SIZE_BOOT=$((512 * 1024))
SIZE_EFI=$((200 * 1024 * 1024))
SIZE_SWAP=$((8 * 1024 * 1024 * 1024))

for DEVICE in ${DEVICES}; do
	DEVICE=${DEVICE##/dev/}
	if [ -z "$(echo ${DEVICE} | grep -i "^[a-z][a-z]*[0-9][0-9]*$")" ]; then
		continue
	fi
	if diskinfo ${DEVICE} > /tmp/diskinfo.tmp 2> /dev/null; then
		SIZE=$(cat /tmp/diskinfo.tmp | awk '{ print $3 }')
		eval "${DEVICE}_size=${SIZE}"
		DISKS="${DISKS} ${DEVICE}"
	fi
done

SDISKS=

for DISK in ${DISKS}; do
	eval SIZE=\$${DISK}_size
	SDISKS="${SDISK}\"${DISK}\" \"${DISK} ($((SIZE / 1024 /1024 / 1024))G)\"
"
done

exec 3>&1
DISK=`echo ${SDISKS} | xargs dialog --backtitle "HardenedBSD Installer" \
	--title "Select target disk" --cancel-label "Abort" \
	--menu "Choose one of the following disk to install." \
	0 40 0 2>&1 1>&3` || exit 1
exec 3>&-

eval SIZE=\$${DISK}_size

SIZE_ROOT=$((SIZE - SIZE_EFI - SIZE_BOOT - SIZE_SWAP))

bsdinstall scriptedpart ${DISK} gpt { ${SIZE_EFI} efi, ${SIZE_BOOT} freebsd-boot, ${SIZE_ROOT} freebsd-ufs /, auto freebsd-swap }

# XXX only if ok

dd if=/boot/boot1.efifat of=/dev/${DISK}p1
gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 2 ${DISK}

# XXX modify labels
