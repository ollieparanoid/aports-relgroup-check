#!/bin/sh -e
# shellcheck shell=dash
# Copyright 2019 Oliver Smith
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Check if all aports of the same relgroup have the same pkgver. This script
# must not depend on abuild to support use cases where the script runs without
# Alpine being installed (git push hook on random distro, pmOS CI, ...).

# Find all APKBUILDs
[ -n "$1" ] && APORTS="$1"
[ -z "$APORTS" ] && APORTS="$PWD"
if ! [ -e "$APORTS/main/build-base" ]; then
	echo "usage: $(basename "$0") [APORTS]"
	echo
	echo "APORTS is the path to your aports dir, you can either set it as"
	echo "       argument as shown above, or as environment variable, or"
	echo "       run this script from within your aports dir"
	exit 1
fi
cd "$APORTS"
APKBUILDS="$(find . -name APKBUILD)"

# All relgroup lines must start with 'relgroup="..."'. So we can use grep to
# find relevant APKBUILDs and avoid running a shell parser for each one.
test_relgroups_invalid() {
	local regex='relgroup="[a-zA-Z0-9_.]*"'
	local invalid

	# shellcheck disable=SC2086
	invalid="$(grep -r "^relgroup=" $APKBUILDS | grep -v ":$regex" | sort)"
	[ -z "$invalid" ] && return 0

	echo "ERROR: relgroup lines found that don't start with '$regex'."
	echo "$invalid" | sed -e 's/^/       /'
	return 1
}

# Source APKBUILD in subshell and print pkgver
# $1: path to APKBUILD
apkbuild_read_pkgver() {
	# shellcheck disable=SC1090
	( . "$1"; echo "$pkgver" )
}

# Print each pkgver and APKBUILD path (aligned for easy debugging)
# $1: space separated list of APKBUILD paths
apkbuilds_print_pkgver() {
	for apkbuild in $1; do
		echo "       pkgver=\"$(apkbuild_read_pkgver "$apkbuild")\": $apkbuild"
	done
}

# Print all relgroups used in aports
relgroups_find() {
	# shellcheck disable=SC2086
	grep -hr "^relgroup=\"" $APKBUILDS | cut -d \" -f 2 | sort -u
}

# Print full paths to APKBUILDs using a certain relgroup
# $1: relgroup
apkbuilds_find_by_relgroup() {
	# shellcheck disable=SC2086
	grep -lr "^relgroup=\"$1\"" $APKBUILDS | cut -d : -f 1 | sort
}

# All aports in one relgroup must have the same pkgver
test_relgroups_inconsistent() {
	local ret=0

	for relgroup in $(relgroups_find); do
		local pkgver=""
		local apkbuilds_relgroup
		apkbuilds_relgroup="$(apkbuilds_find_by_relgroup "$relgroup")"
		for apkbuild in $apkbuilds_relgroup; do
			local current
			current="$(apkbuild_read_pkgver "$apkbuild")"
			if [ -z "$pkgver" ]; then
				pkgver="$current"
			elif [ "$pkgver" != "$current" ]; then
				echo "ERROR: relgroup '$relgroup' is inconsistent:"
				apkbuilds_print_pkgver "$apkbuilds_relgroup"
				ret=1
				break
			fi
		done
	done

	return $ret
}

# Run both tests
if test_relgroups_invalid && test_relgroups_inconsistent; then
	echo "*** relgroup check successful"
else
	echo "*** relgroup check failed!"
	exit 1
fi
