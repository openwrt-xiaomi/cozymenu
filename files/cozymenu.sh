#!/bin/sh
#
# Copyright (C) 2023 remittor
#

CM_PROGNAME="cozymenu"
CM_PROGDIR="/usr/share/$CM_PROGNAME"
CM_LOGPREF=$CM_PROGNAME

cmlog() {
	logger -t $CM_LOGPREF "$@"
}
 
cmerr() {
	logger -t $CM_LOGPREF -p err "$@"
}

cmdie() {
	cmerr "$@"
	echo "========================================================="
	sleep 1
	exit 1
}

cm_sed_path() {
	local str=$( ( echo $1|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\\]/g' )>&1 )
	echo "$str"
}

cm_reload_luci() {
	rm -f /tmp/luci-index*
	rm -rf /tmp/luci-modulecache
	luci-reload
	return 0
}

CM_MENU_ORIG_FN="/usr/share/ucode/luci/dispatcher.uc"
CM_MENU_HOOK_FN="/usr/share/ucode/luci/$CM_PROGNAME.uc"
CM_MENU_HOOK_FUNC="cozymenu_hook"

#############################
#import { hash, load_catalog, change_catalog, translate, ntranslate, getuid } from 'luci.core';
#import { revision as luciversion, branch as luciname } from 'luci.version';
#import { default as LuCIRuntime } from 'luci.runtime';
#import { urldecode } from 'luci.http';
#############################

cm_patch_import() {
	local cmd
	local xx
	if [ ! -f "$CM_MENU_ORIG_FN" ]; then
		return 1
	fi
	xx=$( grep -c -F "$CM_MENU_HOOK_FN" "$CM_MENU_ORIG_FN" )
	if [ "$xx" != "0" ]; then
		cmlog 'File "'"$( basename $CM_MENU_ORIG_FN )"'" already patched (import)'
		return 0
	fi
	cmd="import { $CM_MENU_HOOK_FUNC } from '$CM_MENU_HOOK_FN';"
	cmd=$( cm_sed_path "$cmd" )
	sed -i "/'luci.runtime'/a $cmd" $CM_MENU_ORIG_FN
	xx=$( grep -c -F "$CM_MENU_HOOK_FN" "$CM_MENU_ORIG_FN" )
	if [ "$xx" = "0" ]; then
		cmerr "Fail on patch import into $CM_MENU_ORIG_FN"
		return 1
	fi
	cmlog 'File "'"$( basename $CM_MENU_ORIG_FN )"'" succefully patched (import)'
	return 0
}

#############################
#function menu_json(acl) {
#	tree ??= build_pagetree();
#
#	if (acl)
#		apply_tree_acls(tree, acl);
#
#	return tree;
#}
#############################

cm_patch_funcmenu() {
	local cmd
	local xx
	if [ ! -f "$CM_MENU_ORIG_FN" ]; then
		return 1
	fi
	xx=$( grep -c -F "$CM_MENU_HOOK_FUNC(" "$CM_MENU_ORIG_FN" )
	if [ "$xx" != "0" ]; then
		cmlog 'File "'"$( basename $CM_MENU_ORIG_FN )"'" already patched (func)'
		return 0
	fi
	cmd="tree = $CM_MENU_HOOK_FUNC(tree);"
	cmd=$( cm_sed_path "$cmd" )
	sed -i "/build_pagetree(/a $cmd" $CM_MENU_ORIG_FN
	xx=$( grep -c -F "$CM_MENU_HOOK_FUNC(" "$CM_MENU_ORIG_FN" )
	if [ "$xx" = "0" ]; then
		cmerr "Fail on patch func into $CM_MENU_ORIG_FN"
		return 1
	fi
	cmlog 'File "'"$( basename $CM_MENU_ORIG_FN )"'" succefully patched (func)'
	return 0
}

cm_remove_all_hooks() {
	sed -i "/$CM_MENU_HOOK_FUNC/d" $CM_MENU_ORIG_FN
	rm -f "$CM_MENU_HOOK_FN"
}

cm_install_menu_hooks() {
	local cmfn
	cmlog "cm_install_menu_hooks"
	cmfn="$CM_PROGDIR/$CM_PROGNAME.uc"
	if [ -f "$CM_MENU_HOOK_FN" ]; then
		cmlog 'File "'"$( basename $CM_MENU_HOOK_FN )"'" already installed'
		return 0
	fi
	cp -f "$cmfn" "$CM_MENU_HOOK_FN"
	if [ ! -f "$CM_MENU_HOOK_FN" ]; then
		cmerr 'FATAL ERROR: File "'"$( basename $CM_MENU_HOOK_FN )"'" could not copy'
		cm_remove_all_hooks
		return 1
	fi
	chmod 644 "$CM_MENU_HOOK_FN"
	cm_patch_import
	[ $? != 0 ] && { cm_remove_all_hooks ; return 1; }
	cm_patch_funcmenu
	[ $? != 0 ] && { cm_remove_all_hooks ; return 1; }
	cm_reload_luci
	return 0
}

cm_remove_menu_hooks() {
	cmlog "cm_remove_menu_hooks"
	cm_remove_all_hooks
	cm_reload_luci
	return 0
}

# ===================================================================

usage() {
	cat << EOF

Usage:
 $CM_PROGNAME [options] -- command

Commands:
start         install cozy menu patches
stop          remove cozy menu patches

Parameters:
 -h           show this help and exit
 -d           show debug messages
EOF
}

usage_err() {
	printf %s\\n "$CM_PROGNAME: $@" >&2
	usage >&2
	exit 1
}

while getopts ":hd" OPT; do
	case "$OPT" in
		h)	usage; exit 0;;
		d)	CM_DEBUG=1;;
		:)	usage_err "option -$OPTARG missing argument";;
		\?)	usage_err "invalid option -$OPTARG";;
		*)	usage_err "unhandled option -$OPT $OPTARG";;
	esac
done
shift $((OPTIND - 1 ))	# OPTIND is 1 based

case "$1" in
	boot)
		cmlog "boot"
		cm_install_menu_hooks
		exit 0
		;;
	start)
		cmlog "start"
		cm_install_menu_hooks
		exit 0
		;;
	stop)
		cmlog "stop"
		cm_remove_menu_hooks
		exit 0
		;;
	reload)
		cmlog "reload"
		cm_reload_luci
		exit 0
		;;
	*)
		usage_err "unknown command - $1";;
esac
