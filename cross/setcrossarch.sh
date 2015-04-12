#!/bin/sh

set -e

# Copyright (C) 2009, 2010  Neil Williams <codehelp@debian.org>
#
# This package is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# meant to be called from multistrap with directory arch variables.
dir=$1
hostarch=$2

if [ -z "$dir" ]; then
	echo "No directory specified."
	exit 1
fi

#run chroot script to ensure no unwanted system interactions (e.g. startup scripts)
if [ -x /usr/share/multistrap/chroot.sh ]; then
   /usr/share/multistrap/chroot.sh $dir $hostarch
fi

cfg="/etc/pdebuild-cross/pdebuild-cross.rc"
if [ -f $cfg ]; then
	. $cfg
fi

if [ -z "$CROSSARCH" ]; then
	# get crossarch from dpkg-cross - check if it is not None
	if [ -f /etc/dpkg-cross/cross-compile ]; then
		DEFARCH=`grep "^default_arch" /etc/dpkg-cross/cross-compile|sed -e 's/default_arch *= *\(.*\)/\1/'`
		if [ -n "$DEFARCH" -a "$DEFARCH" != "None" ]; then
			CROSSARCH="$DEFARCH"
		fi
	else
		echo "No CROSSARCH set in '$cfg' and no dpkg-cross default: using armel."
		CROSSARCH="armel"
	fi
fi

# set the value inside the chroot
echo "#!/bin/sh" > $dir/tmp/set.sh
echo >> $dir/tmp/set.sh
echo "export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C" >> $dir/tmp/set.sh
echo "echo debconf dpkg-cross/default-arch select $CROSSARCH|debconf-set-selections" >> $dir/tmp/set.sh
echo "Setting debconf dpkg-cross/default-arch to $CROSSARCH"
sudo chroot $dir sh /tmp/set.sh
sudo rm $dir/tmp/set.sh
