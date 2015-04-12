#!/bin/sh
#
# Copyright 2008 Hands.com Ltd <phil@hands.com>
# Copyright 2008 Neil Williams <codehelp@debian.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.

initd="/etc/init.d"
etcd="/etc/rc.d"
bn=$1;shift
if [ "$bn" = '-f' ]; then
	bn=$1
	shift
fi

defaults () {
	makelinks "S${1:-20}"
	makelinks "K${2:-${1:-20}}"
}

makelinks () {
	echo " Adding symlink for $initd/$bn ...";
	echo "${etcd}/${1}${bn} -> ../init.d/$bn"
	ln -s "../init.d/$bn" "${etcd}/${1}${bn}"
}

if [ -z "$bn" -o -z "$1" ]; then
	echo "Insufficient arguments"
	exit 1
fi
if [ ! -f "$initd/$bn" ]; then
	echo "update-rc.d: $initd/$bn: file does not exist"
	echo
	exit 1
fi
if [ "$1" = 'remove' ]; then
	shift
	echo "rm -f /etc/rc.d/*${bn}"
	rm -f "/etc/rc.d/*${bn}"
	exit;
elif [ "$1" = 'defaults' ]; then
	makelinks "S${2:-20}"
	makelinks "K${3:-${2:-20}}"
	exit 0;
else
	if [ "$1" = 'start' ]
	then
		shift
		num=$1
		# use two digit prefixes
		if [ $num -lt 10 ]; then
			num="0${num}"
		fi
		makelinks "S${num}"
		while [ "$1" != "." ]
		do
			shift
		done
		shift
		if [ "$1" = 'stop' ]; then
			shift
			makelinks "K${1}"
		fi
	fi
	exit 0;
fi
