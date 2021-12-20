#!/bin/sh
#-
# Copyright (c) 2019-2021 Franco Fichtner <franco@opnsense.org>
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

SIZE_BOOT=$((512 * 1024))
SIZE_EFI=$((200 * 1024 * 1024))
SIZE_MIN=$((4 * 1024 * 1024 * 1024))
SIZE_SWAP=$((8 * 1024 * 1024 * 1024))
SIZE_SWAPMIN=$((30 * 1024 * 1024 * 1024))

OPNSENSE_IMPORTER="/usr/local/sbin/opnsense-importer"

opnsense_load_disks()
{
	OPNSENSE_SDISKS=
	OPNSENSE_DISKS=

	for DEVICE in $(find /dev -d 1 \! -type d); do
		DEVICE=${DEVICE##/dev/}

		if [ -z "$(echo ${DEVICE} | grep -ix "[a-z][a-z]*[0-9][0-9]*")" ]; then
			continue
		fi

		if [ -n "$(echo ${DEVICE} | grep -i "^tty")" ]; then
			continue
		fi

		if diskinfo ${DEVICE} > /tmp/diskinfo.tmp 2> /dev/null; then
			SIZE=$(cat /tmp/diskinfo.tmp | awk '{ print $3 }')
			eval "export ${DEVICE}_size=${SIZE}"

			NAME=$(dmesg | grep "^${DEVICE}:" | head -n 1 | cut -d ' ' -f2- | tr -d '<' | cut -d '>' -f1 | tr -cd "[:alnum:][:space:]")
			eval "export ${DEVICE}_name=\"${NAME:-Unknown disk}\""

			OPNSENSE_DISKS="${OPNSENSE_DISKS} ${DEVICE}"
		fi
	done

	for DISK in ${OPNSENSE_DISKS}; do
		eval SIZE=\$${DISK}_size
		eval NAME=\$${DISK}_name
		OPNSENSE_SDISKS="${OPNSENSE_SDISKS}\"${DISK}\" \"<${NAME}> ($((SIZE / 1024 /1024 / 1024))GB)\"
"
	done

	export OPNSENSE_SDISKS # disk menu
	export OPNSENSE_DISKS # raw disks

	OPNSENSE_SPOOLS=
	OPNSENSE_POOLS=

	ZFSPOOLS=$(${OPNSENSE_IMPORTER} -z | tr ' ' ',')

	for ZFSPOOL in ${ZFSPOOLS}; do
		ZFSNAME=$(echo ${ZFSPOOL} | awk -F, '{ print $1 }')
		ZFSGUID=$(echo ${ZFSPOOL} | awk -F, '{ print $2 }')
		ZFSSIZE=$(echo ${ZFSPOOL} | awk -F, '{ print $3 }')
		OPNSENSE_POOLS="${OPNSENSE_POOLS} ${ZFSNAME}"
		OPNSENSE_SPOOLS="${OPNSENSE_SPOOLS}\"${ZFSNAME}\" \"<${ZFSGUID}> (${ZFSSIZE})\"
"
	done

	export OPNSENSE_SPOOLS # zfs pool menu
	export OPNSENSE_POOLS # raw zfs pools
}

opnsense_info()
{
	dialog --backtitle "OPNsense Installer" --title "${1}" \
	    --msgbox "${2}" 0 0
}

opnsense_fatal()
{
	dialog --backtitle "OPNsense Installer" --title "${1}" \
	    --ok-label "Cancel" --msgbox "${2}" 0 0
	exit 1
}
