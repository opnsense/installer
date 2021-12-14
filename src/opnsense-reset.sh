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

. /usr/libexec/bsdinstall/opnsense.subr || exit 1

opnsense_load_disks

PASS1=$(mktemp /tmp/passwd.XXXXXX)
PASS2=$(mktemp /tmp/passwd.XXXXXX)
PASSIN=
PASSOK=

[ -z "${OPNSENSE_SDISKS}${OPNSENSE_SPOOLS}" ] && opnsense_fatal "Reset Password" "No suitable disks found in the system"

exec 3>&1
DISK=`echo ${OPNSENSE_SDISKS} ${OPNSENSE_SPOOLS} | xargs dialog --backtitle "OPNsense Installer" \
	--title "Reset Password" --cancel-label "Cancel" \
	--menu "Please select a disk to continue." \
	0 0 0 2>&1 1>&3` || exit 1
exec 3>&-

[ -z "${DISK}" ] && opnsense_fatal "Reset Password" "No valid disk was selected"

while [ -z "${PASSIN}" ]; do
	if ! dialog --backtitle "OPNsense Installer" --title "Reset Password" --clear --insecure "${@}" \
	    --passwordbox "Please select a password for the\nsystem management account (root):" 9 40 2> ${PASS1}; then
	    exit 0
	fi
	PASSIN=$(cat ${PASS1})
done

while [ -z "${PASSOK}" ]; do
	if ! dialog --backtitle "OPNsense Installer" --title "Reset Password" --clear --insecure "${@}" \
	    --passwordbox "Please confirm the password for the\nsystem management account (root):" 9 40 2> ${PASS2}; then
	    exit 0
	fi
	PASSOK=$(cat ${PASS2})
done

if diff -uq ${PASS1} ${PASS2} > /dev/null; then
	if (cat ${PASS1}; echo) | ${OPNSENSE_IMPORTER} -p ${DISK} 2>&1; then
		opnsense_info "Reset Password" "Password reset completed"
	else
		opnsense_fatal "Reset Password" "Password reset failed"
	fi
else
	dialog --backtitle "OPNsense Installer" --title "Reset Password" "${@}" \
	    --ok-label "Back" --msgbox "The entered passwords did not match." 5 40
fi

rm -f /tmp/passwd.*
