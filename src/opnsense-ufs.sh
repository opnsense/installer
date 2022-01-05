#!/bin/sh
#-
# Copyright (c) 2021-2022 Franco Fichtner <franco@opnsense.org>
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

. /usr/libexec/bsdinstall/opnsense.subr || exit 1

fatal()
{
	dialog --backtitle "OPNsense Installer" --title "UFS Configuration" \
	    --ok-label "Cancel" --msgbox "${1}" 0 0
	exit 1
}

MEM=$(sysctl -n hw.realmem)
MEM=$((MEM / 1024 / 1024))
MEM_MIN=$((2 * 1000)) # a little lower to account for missing pages

if [ ${MEM} -lt ${MEM_MIN} ]; then
	if ! dialog --backtitle "OPNsense Installer" --title "UFS Configuration" \
	    --yes-label "Proceed anyway" --no-label "Cancel" --yesno \
	    "The installer detected only ${MEM}MB of RAM. Since\n
this is a live image, copying the full file system\n
to another disk requires at least ${MEM_MIN}MB of RAM\n
and is generally advised for good operation." 0 0; then
		exit 1
	fi
fi

opnsense_load_disks

[ -z "${OPNSENSE_SDISKS}" ] && fatal "No suitable disks found in the system"

exec 3>&1
DISK=`echo ${OPNSENSE_SDISKS} | xargs dialog --backtitle "OPNsense Installer" \
	--title "UFS Configuration" --cancel-label "Cancel" \
	--menu "Please select a disk to continue." \
	0 0 0 2>&1 1>&3` || exit 1
exec 3>&-

eval SIZE=\$${DISK}_size

[ -z "${SIZE}" ] && fatal "No valid disk was selected"
[ ${SIZE} -lt ${SIZE_MIN} ] && fatal "The minimum size $((SIZE_MIN / 1024 / 1024 / 1024))GB was not met"

ARGS_SWAP=", auto freebsd-swap"
SED_SWAP="-e s:/${DISK}p4:/gpt/swapfs:"

if [ ${SIZE} -lt ${SIZE_SWAPMIN} ]; then
	SIZE_SWAP=0
elif ! dialog --backtitle "OPNsense Installer" --title "UFS Configuration" --yesno \
    "Continue with a recommended swap partition of size $((SIZE_SWAP / 1024 / 1024 / 1024))GB?" 6 40; then
	SIZE_SWAP=0
fi

if [ ${SIZE_SWAP} -eq 0 ]; then
	ARGS_SWAP=
	SED_SWAP=
fi

SIZE_ROOT=$((SIZE - SIZE_EFI - SIZE_BOOT - SIZE_SWAP))

if ! dialog --backtitle "OPNsense Installer" --title "UFS Configuration" \
    --yes-label YES --no-label NO --default-button no --yesno \
    "Last Chance! Are you sure you want to destroy the current contents of the following disks:\n\n    ${DISK}\n\n" 0 0; then
	exit 1
fi

bsdinstall scriptedpart ${DISK} gpt { ${SIZE_EFI} efi, ${SIZE_BOOT} freebsd-boot, ${SIZE_ROOT} freebsd-ufs /${ARGS_SWAP} } || \
    fatal "The partition editor run failed"

gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 2 ${DISK} > /dev/null || fatal "GPT boot partition write failed"

gpart modify -i 1 -l efifs ${DISK} > /dev/null || fatal "Disk label failed (efi)"
gpart modify -i 2 -l bootfs ${DISK} > /dev/null || fatal "Disk label failed (boot)"
gpart modify -i 3 -l rootfs ${DISK} > /dev/null || fatal "Disk label failed (root)"
[ ${SIZE_SWAP} -gt 0 ] && ( gpart modify -i 4 -l swapfs ${DISK} > /dev/null || fatal "Disk label failed (swap)" )

cp ${BSDINSTALL_TMPETC}/fstab ${BSDINSTALL_TMPETC}/fstab.bak
if ! sed -e "s:/${DISK}p3:/gpt/rootfs:" -e "s:/${DISK}p1:/gpt/efifs:" ${SED_SWAP} \
    ${BSDINSTALL_TMPETC}/fstab.bak > ${BSDINSTALL_TMPETC}/fstab; then
    fatal "Disk label not replaced"
fi
rm ${BSDINSTALL_TMPETC}/fstab.bak
