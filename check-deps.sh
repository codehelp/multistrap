#!/bin/sh

set -e

#  Copyright 2010 Neil Williams <codehelp@debian.org>
#  Copyright 2010 Philip Hands <phil@hands.com>

#  This package is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# using the package directly means we don't have to deal
# with multiline Depends

while [ -n "$1" ]; do
case "$1" in
	-\?|-h|--help)
		shift
		echo "-f path to a .deb filename; -i install the packages now."
		exit 0
	;;
	-f|--file)
		shift
		FILE=$1
		shift
	;;
	-i|--install)
		shift
		INSTALL=1
	;;
	-y|--yes)
		shift
		YES=1
	;;
	*)
		FILE=$1
		shift
	;;
esac
done

if [ ! -f "$FILE" -o ! -r "$FILE" ]; then
	echo "Please specify a path to a debian package file with the -f command."
	exit 2
fi

DEPS=$(dpkg-deb -f $FILE Depends) || exit 3
IFS=,
CMD=
ERR=
for pkg in $DEPS; do
	CHECK=
	name=$(echo $pkg|sed -e 's/^ //'|cut -d' ' -f1)
	if [ "apt" = "$name" ]; then
		continue
	fi
	if [ -z "$name" ]; then
		continue
	fi
	orlist=$(echo $pkg|grep "|" || true)
	while [ -n "$orlist" ]; do
		ORPKG=`echo $pkg|cut -d'|' -f2|sed -e 's/^ //'`
		ALTERNATE="$ALTERNATE $ORPKG"
		orlist=$(echo $orlist | sed -e "s/.*$ORPKG//;s/^ *//;s/ *$//")
		ALTERNATE=$(echo $ALTERNATE|sed -e 's/^ *//;s/ *$//')
		pkg=$(echo $pkg|sed -e "s/|//;s/$ORPKG//;s/^ *//;s/ *$//")
	done
	if [ -n `echo $pkg|grep '('` ]; then
		VERLIMIT=`echo $pkg|cut -d'(' -f2|tr -d ')'|tr -d '\n'|grep -v $name || true`
		VERCMP=`echo $VERLIMIT|sed -e 's/\(.*\) \(.*\)/\1/'`
		VERLIMIT=`echo $VERLIMIT|sed -e 's/\(.*\) \(.*\)/\2/'`
	fi
	POLICY=`LC_ALL=C apt-cache policy $name 2>/dev/null|grep Candidate|cut -d':' -f2-3|tr -d ' '`
	if [ -n "$POLICY" ]; then
		if [ -n "$VERLIMIT" ]; then
			set +e
			CHECK=`dpkg --compare-versions $POLICY "$VERCMP" $VERLIMIT ; echo $?`
			set -e
			if [ -z "$CHECK" ]; then
				VERLIMIT=
				VERCMP=
				name=$(echo $ALTERNATE|sed -e 's/^ //'|cut -d' ' -f1)
				if [ -n `echo $ALTERNATE|grep '('` ]; then
					VERLIMIT=`echo $ALTERNATE|cut -d'(' -f2|tr -d ')'|tr -d '\n'|grep -v $name || true`
					VERCMP=`echo $VERLIMIT|sed -e 's/\(.*\) \(.*\)/\1/'`
					VERLIMIT=`echo $VERLIMIT|sed -e 's/\(.*\) \(.*\)/\2/'`
				fi
				POLICY=`LC_ALL=C apt-cache policy $name 2>/dev/null|grep Candidate|cut -d':' -f2-3|tr -d ' '`
				if [ -n "$POLICY" ]; then
					if [ -n "$VERLIMIT" ]; then
						set +e
						CHECK=`dpkg --compare-versions $POLICY "$VERCMP" $VERLIMIT ; echo $?`
						set -e
					fi
				fi
			fi
		fi
	else
		ERR="$ERR $name "
	fi
	if [ -z "$CHECK" -o "0" != "$CHECK" ]; then
		if [ -n "$VERCMP" ]; then
			echo "$name ($VERCMP $VERLIMIT) is NOT available."
			ERR="$ERR $name ($VERCMP $VERLIMIT) "
		fi
	fi
	if [ -n "$YES" ]; then
		CMD="$CMD -y $name"
	fi
	MISSING=`dpkg-query -W -f '\${Status}' $name 2>/dev/null | grep "install ok installed"|sed -e 's/ //g'`
	if [ -z "$MISSING" ]; then
		CMD="$CMD $name"
	fi
done
if [ -n "$ERR" ]; then
	echo Some packages are not available: $ERR
	exit 1
fi
if [ -n "$INSTALL" ]; then
	eval apt-get install "$CMD"
	dpkg -i $FILE
elif [ -n "$CMD" ]; then
	echo apt-get install ${CMD}
fi
