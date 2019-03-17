#!/bin/sh
#-
# Copyright (c) 2011 Nathan Whitehorn
# Copyright (c) 2013 Devin Teske
# Copyright (c) 2019 Franco Fichtner <franco@opnsense.org>
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
# $FreeBSD$
#
############################################################ INCLUDES

BSDCFG_SHARE="/usr/share/bsdconfig"
. $BSDCFG_SHARE/common.subr || exit 1
f_include $BSDCFG_SHARE/dialog.subr

############################################################ FUNCTIONS

PRODUCT_NAME="OPNsense"
PRODUCT_VERSION="19.7"

error() {
	local msg
	if [ -n "$1" ]; then
		msg="$1\n\n"
	fi
	test -f $PATH_FSTAB && bsdinstall umount
	dialog --backtitle "${PRODUCT_NAME} Installer" --title "Abort" \
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

dialog --backtitle "${PRODUCT_NAME} Installer" \
    --title "${PRODUCT_NAME} ${PRODUCT_VERSION}" \
    --ok-label "Ok, let's go." --msgbox "
Welcome to the ${PRODUCT_NAME} ${PRODUCT_VERSION} installer!

Before we begin, you will be asked a
few questions so that this installation
environment can be set up to suit your
needs.

You will then be presented a menu of
items from which you may select to
install a new system, with or without
importing a previous configuration.
" 0 0

bsdinstall keymap

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

PMODES="\
Guided \"Guided installation\" \
Manual \"Manual installation\" \
Import \"Import configuration\" \
Reset \"Reset Password\" \
Reboot \"Reboot\" \
Exit \"Exit\""

#CURARCH=$( uname -m )
#case $CURARCH in
#	amd64|arm64|i386)	# Booting ZFS Supported
#		PMODES="$PMODES \"Auto (ZFS)\" \"Guided Root-on-ZFS\""
#		;;
#	*)		# Booting ZFS Unspported
#		;;
#esac

exec 3>&1
PARTMODE=`echo $PMODES | xargs dialog --backtitle "${PRODUCT_NAME} Installer" \
	--title "Select Task" --no-cancel \
	--menu "How would you like to partition your disk?" \
	0 0 0 2>&1 1>&3` || exit 1
exec 3>&-

case "$PARTMODE" in
"Guided")	# Guided
	bsdinstall autopart || error "Partitioning error"
	bsdinstall mount || error "Failed to mount filesystem"
	;;
"Manual")	# Manual
	if f_isset debugFile; then
		# Give partedit the path to our logfile so it can append
		BSDINSTALL_LOG="${debugFile#+}" bsdinstall partedit || error "Partitioning error"
	else
		bsdinstall partedit || error "Partitioning error"
	fi
	bsdinstall mount || error "Failed to mount filesystem"
	;;
#"Auto (ZFS)")	# ZFS
#	bsdinstall zfsboot || error "ZFS setup failed"
#	bsdinstall mount || error "Failed to mount filesystem"
#	;;
"Reboot")
	# XXX
	echo reboot
	exit 0
	;;
*)
	exit 0
	;;
esac

# XXX install routines
# bsdinstall checksum || error "Distribution checksum failed"
# bsdinstall distextract || error "Distribution extract failed"
# bsdinstall rootpass || error "Could not set root password"

bsdinstall config  || error "Failed to save config"

dialog --backtitle "${PRODUCT_NAME} Installer" --title "Manual Configuration" \
    --default-button no --yesno \
   "The installation is now finished. Before exiting the installer, would you like to open a shell in the new system to make any final manual modifications?" 0 0
if [ $? -eq 0 ]; then
	clear
	echo This shell is operating in a chroot in the new system. \
	    When finished making configuration changes, type \"exit\".
	chroot "$BSDINSTALL_CHROOT" /bin/sh 2>&1
fi

bsdinstall entropy
bsdinstall umount

f_dprintf "Installation Completed at %s" "$( date )"

################################################################################
# END
################################################################################
