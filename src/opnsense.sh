#!/bin/sh
#-
# Copyright (c) 2011 Nathan Whitehorn
# Copyright (c) 2013 Devin Teske
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
#
############################################################ INCLUDES

BSDCFG_SHARE="/usr/share/bsdconfig"
. $BSDCFG_SHARE/common.subr || exit 1
f_include $BSDCFG_SHARE/dialog.subr

############################################################ FUNCTIONS

PRODUCT_NAME=$(opnsense-version -N)
PRODUCT_VERSION=$(opnsense-version -V)

error() {
	local msg
	if [ -n "$1" ]; then
		msg="$1\n\n"
	fi
	test -f $PATH_FSTAB && bsdinstall umount
	dialog --backtitle "OPNsense Installer" --title "Abort" \
	    --no-label "Exit" --yes-label "Restart" --yesno \
	    "${msg}An installation step has been aborted. Would you like to restart the installation or exit the installer?" 0 0
	if [ $? -ne 0 ]; then
		exit 1
	else
		exec $0
	fi
}

hline_arrows_tab_enter="Press arrows, TAB or ENTER"
msg_gpt_active_fix="Your hardware is known to have issues booting in CSM/Legacy/BIOS mode from GPT partitions that are not set active. Would you like the installer to apply this workaround for you?"
msg_lenovo_fix="Your model of Lenovo is known to have a BIOS bug that prevents it booting from GPT partitions without UEFI. Would you like the installer to apply a workaround for you?"
msg_no="NO"
msg_yes="YES"

# dialog_workaround
#
# Ask the user if they wish to apply a workaround
#
dialog_workaround()
{
	local passed_msg="$1"
	local title="$DIALOG_TITLE"
	local btitle="$DIALOG_BACKTITLE"
	local prompt # Calculated below
	local hline="$hline_arrows_tab_enter"

	local height=8 width=50 prefix="   "
	local plen=${#prefix} list= line=
	local max_width=$(( $width - 3 - $plen ))

	local yes no defaultno extra_args format
	if [ "$USE_XDIALOG" ]; then
		yes=ok no=cancel defaultno=default-no
		extra_args="--wrap --left"
		format="$passed_msg"
	else
		yes=yes no=no defaultno=defaultno
		extra_args="--cr-wrap"
		format="$passed_msg"
	fi

	# Add height for Xdialog(1)
	[ "$USE_XDIALOG" ] && height=$(( $height + $height / 5 + 3 ))

	prompt=$( printf "$format" )
	f_dprintf "%s: Workaround prompt" "$0"
	$DIALOG \
		--title "$title"        \
		--backtitle "$btitle"   \
		--hline "$hline"        \
		--$yes-label "$msg_yes" \
		--$no-label "$msg_no"   \
		$extra_args             \
		--yesno "$prompt" $height $width
}

############################################################ MAIN

f_dprintf "Began Installation at %s" "$( date )"

rm -rf $BSDINSTALL_TMPETC
mkdir $BSDINSTALL_TMPETC

trap true SIGINT	# This section is optional

[ -z "${BSDINSTALL_KEYMAP_DONE}" ] && bsdinstall keymap
export BSDINSTALL_KEYMAP_DONE=1

trap error SIGINT	# Catch cntrl-C here

rm -f $PATH_FSTAB
touch $PATH_FSTAB

#
# Try to detect known broken platforms and apply their workarounds
#

if f_interactive; then
	sys_maker=$( kenv -q smbios.system.maker )
	f_dprintf "smbios.system.maker=[%s]" "$sys_maker"
	sys_model=$( kenv -q smbios.system.product )
	f_dprintf "smbios.system.product=[%s]" "$sys_model"
	sys_version=$( kenv -q smbios.system.version )
	f_dprintf "smbios.system.version=[%s]" "$sys_version"
	sys_mb_maker=$( kenv -q smbios.planar.maker )
	f_dprintf "smbios.planar.maker=[%s]" "$sys_mb_maker"
	sys_mb_product=$( kenv -q smbios.planar.product )
	f_dprintf "smbios.planar.product=[%s]" "$sys_mb_product"

	#
	# Laptop Models
	#
	case "$sys_maker" in
	"LENOVO")
		case "$sys_version" in
		"ThinkPad X220"|"ThinkPad T420"|"ThinkPad T520"|"ThinkPad W520"|"ThinkPad X1")
			dialog_workaround "$msg_lenovo_fix"
			retval=$?
			f_dprintf "lenovofix_prompt=[%s]" "$retval"
			if [ $retval -eq $DIALOG_OK ]; then
				export ZFSBOOT_PARTITION_SCHEME="GPT + Lenovo Fix"
				export WORKAROUND_LENOVO=1
			fi
			;;
		esac
		;;
	"Dell Inc.")
		case "$sys_model" in
		"Latitude E6330"|"Latitude E7440"|"Latitude E7240"|"Precision Tower 5810")
			dialog_workaround "$msg_gpt_active_fix"
			retval=$?
			f_dprintf "gpt_active_fix_prompt=[%s]" "$retval"
			if [ $retval -eq $DIALOG_OK ]; then
				export ZFSBOOT_PARTITION_SCHEME="GPT + Active"
				export WORKAROUND_GPTACTIVE=1
			fi
			;;
		esac
		;;
	"Hewlett-Packard")
		case "$sys_model" in
		"HP ProBook 4330s")
			dialog_workaround "$msg_gpt_active_fix"
			retval=$?
			f_dprintf "gpt_active_fix_prompt=[%s]" "$retval"
			if [ $retval -eq $DIALOG_OK ]; then
				export ZFSBOOT_PARTITION_SCHEME="GPT + Active"
				export WORKAROUND_GPTACTIVE=1
			fi
			;;
		esac
		;;
	esac
	#
	# Motherboard Models
	#
	case "$sys_mb_maker" in
	"Intel Corporation")
		case "$sys_mb_product" in
		"DP965LT"|"D510MO")
			dialog_workaround "$msg_gpt_active_fix"
			retval=$?
			f_dprintf "gpt_active_fix_prompt=[%s]" "$retval"
			if [ $retval -eq $DIALOG_OK ]; then
				export ZFSBOOT_PARTITION_SCHEME="GPT + Active"
				export WORKAROUND_GPTACTIVE=1
			fi
			;;
		esac
		;;
	"Acer")
		case "$sys_mb_product" in
		"Veriton M6630G")
			dialog_workaround "$msg_gpt_active_fix"
			retval=$?
			f_dprintf "gpt_active_fix_prompt=[%s]" "$retval"
			if [ $retval -eq $DIALOG_OK ]; then
				export ZFSBOOT_PARTITION_SCHEME="GPT + Active"
				export WORKAROUND_GPTACTIVE=1
			fi
			;;
		esac
		;;
	esac
fi

CURARCH=$( uname -m )
case $CURARCH in
	amd64|arm64|i386)	# Booting ZFS Supported
		PMODESZFS="\"Auto (ZFS)\" \"Guided Root-on-ZFS\"
"
		CHOICESZFS="\"Install (ZFS)\" \"ZFS GPT/UEFI hybrid\"
"
		;;
	*)		# Booting ZFS Unspported
		;;
esac

PMODES="\
\"Auto (UFS)\" \"Guided Disk Setup\" \
${PMODESZFS}Manual \"Manual Disk Setup (experts)\""

CHOICES="\
\"Install (UFS)\" \"UFS GPT/UEFI hybrid\" \
${CHOICESZFS}\"Other modes\" \"Extended installation\" \
Import \"Import previous config\" \
Reset \"Reset previous password\" \
Reboot \"Reboot this system\""

while :; do

exec 3>&1
CHOICE=`echo ${CHOICES} | xargs dialog --backtitle "OPNsense Installer" \
	--title "${PRODUCT_NAME} ${PRODUCT_VERSION}" --cancel-label "Exit" \
	--menu "Choose one of the following tasks to perform." \
	0 0 0 2>&1 1>&3` || exit 1
exec 3>&-

case "${CHOICE}" in
"Install (UFS)")
	bsdinstall opnsense-ufs || error "Partitioning error"
	bsdinstall mount || error "Failed to mount filesystem"
	break
	;;
"Install (ZFS)")
	bsdinstall opnsense-zfs || error "Partitioning error"
	bsdinstall mount || error "Failed to mount filesystem"
	break
	;;
"Other modes")
	exec 3>&1
	PARTMODE=`echo ${PMODES} | xargs dialog --backtitle "OPNsense Installer" \
	--title "Select Task" --cancel-label "Back" \
	--menu "Choose one of the following tasks to perform." \
	0 0 0 2>&1 1>&3` || PARTMODE=Exit
	exec 3>&-

	case "${PARTMODE}" in
	"Auto (UFS)")	# Guided
		bsdinstall autopart || error "Partitioning error"
		bsdinstall mount || error "Failed to mount filesystem"
		break
		;;
	"Auto (ZFS)")	# ZFS
		bsdinstall zfsboot || error "ZFS setup failed"
		bsdinstall mount || error "Failed to mount filesystem"
		break
		;;
	"Manual")	# Manual
		if f_isset debugFile; then
			# Give partedit the path to our logfile so it can append
			BSDINSTALL_LOG="${debugFile#+}" bsdinstall partedit || error "Partitioning error"
		else
			bsdinstall partedit || error "Partitioning error"
		fi
		bsdinstall mount || error "Failed to mount filesystem"
		break
		;;
	"Exit")
		;;
	*)
		error "Unknown partitioning mode"
		;;
	esac
	;;
"Import")
	bsdinstall opnsense-import || error "Failed to import configuration"
	;;
"Reset")
	bsdinstall opnsense-reset || error "Failed to import configuration"
	;;
"Reboot")
	exit 0 # "this is fine"
	;;
*)
	error "Unknown installer mode"
	;;
esac

done

bsdinstall opnsense-install || error "Failed to install"

# Set up boot loader
bsdinstall bootconfig || error "Failed to configure bootloader"

trap true SIGINT	# This section is optional

finalconfig() {
	exec 3>&1
	REVISIT=$(dialog --backtitle "OPNsense Installer" \
	    --title "Final Configuration" --no-cancel --menu \
	    "Setup of your ${PRODUCT_NAME} system is nearly complete. You can now modify your configuration choices." 0 0 0 \
		"Exit" "Apply configuration and exit installer" \
		"Root Password" "Change root password" 2>&1 1>&3)
	exec 3>&-

	case "$REVISIT" in
	"Root Password")
		bsdinstall opnsense-rootpass
		finalconfig
		;;
	esac
}

# Allow user to change his mind
finalconfig

trap error SIGINT	# SIGINT is bad again

bsdinstall entropy
bsdinstall umount

f_dprintf "Installation Completed at %s" "$( date )"

################################################################################
# END
################################################################################
