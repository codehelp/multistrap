#!/usr/bin/perl

# Copyright (C) 2010  Neil Williams <codehelp@debian.org>
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

use strict;
use warnings;
use Cwd qw (realpath);
use File::Basename;
use POSIX qw(locale_h);
use Locale::gettext;
use vars qw/ @list @seq $file $dir $line @cmd $i $dry
 $msg $progname $ourversion $fakeroot
 $name $type $mode $link $uid $gid $major $minor $start $step $count /;

@list =();
@seq = ();

setlocale(LC_MESSAGES, "");
textdomain("multistrap");
$progname = basename($0);
$ourversion = &our_version();
# default file from mtd-utils.
$file = "/usr/share/doc/multistrap/examples/device_table.txt";
$dir = `pwd`;
chomp ($dir);
$dir .= "/tmp/";
my $e=`LC_ALL=C printenv`;
if ($e !~ /\nFAKEROOTKEY=[0-9]+\n/) {
	$fakeroot = "fakeroot";
} else {
	$fakeroot="";
}

while( @ARGV ) {
	$_= shift( @ARGV );
	last if m/^--$/;
	if (!/^-/) {
		unshift(@ARGV,$_);
		last;
	} elsif (/^(-\?|-h|--help|--version)$/) {
	&usageversion();
		exit( 0 );
	} elsif (/^(-f|--file)$/) {
		$file = shift(@ARGV);
	} elsif (/^(-d|--dir)$/) {
		$dir = shift(@ARGV);
		$dir = realpath ($dir);
	} elsif (/^(-n|--dry-run)$/) {
		$dry++;
	} elsif (/^(--no-fakeroot)$/) {
		$fakeroot="";
	} else {
		die "$progname: "._g("Unknown option")." $_.\n";
	}
}

$msg = sprintf (_g("Need a configuration file - use %s -f\n"), $progname);
die ($msg)
	if (not -f $file);
printf (_g("%s %s using %s\n"), $progname, $ourversion, $file);
open (TABLE, "<", $file) or die ("$progname: $file: $!\n");
@list=<TABLE>;
close (TABLE);

my $ret = 0;
if (not defined $dry) {
	$ret = mkdir ("$dir") if (not -d "$dir");
	$dir = realpath ($dir);
	chomp ($dir);
	$dir .= ($dir =~ m:/$:) ? '' : "/";
	chdir ($dir);
} else {
	push @seq, "mkdir $dir";
	push @seq, "cd $dir";
}

foreach $line (@list) {
	chomp ($line);
	next if ($line =~ /^#/);
	next if ($line =~ /^$/);
	@cmd = split (/\t/, $line);
	next if (scalar @cmd != 10);
	#  0      1      2      3     4    5        6       7      8      9
	($name, $type, $mode, $uid, $gid, $major, $minor, $start, $step, $count) = split (/\t/, $line);
	next if (not defined $type or not defined $count);
	if ($type eq "s") {
		$link = $mode;
		push @seq, "ln -s $name .$link";
		next;
	}
	if ($type eq "h") {
		$link = $mode;
		push @seq, "ln $name .$link";
		next;
	}
	if ($type eq "d"){
		push @seq, "mkdir -m $mode -p .$name";
		next;
	}
	if ($count =~ /-/) {
		push @seq, "mknod .$name $type $major $minor";
		push @seq, "chmod $mode .$name";
		push @seq, "chown $uid:$gid .$name";
	} else {
		for ($i = $start; $i < $count; $i += $step) {
			my $inc = $minor + $i;
			push @seq, "mknod .$name$i $type $major $inc";
			push @seq, "chmod $mode .$name$i";
			push @seq, "chown $uid:$gid .$name$i";
		}
	}
	undef $name;
	undef $type;
	undef $mode;
	undef $uid;
	undef $gid;
	undef $major;
	undef $minor;
	undef $start;
	undef $step;
	undef $count;
}
if (defined $dry) {
	print join ("\n", @seq);
	print "\n";
} else {
	foreach my $node (@seq) {
		system ("$fakeroot $node");
	}
}

sub our_version {
	my $query = `dpkg-query -W -f='\${Version}' multistrap 2>/dev/null`;
	(defined $query) ? return $query : return "2.1.10";
}

sub usageversion {
	printf STDERR (_g("
%s version %s

 %s [-n|--dry-run] [-d DIR] [-f FILE]
 %s -?|-h|--help|--version
"), $progname, $ourversion, $progname, $progname);
}

sub _g {
    return gettext(shift);
}

=pod

=head1 Name

device-table.pl - parses simple device tables and passes to mknod

=head1 Synopsis

 device-table.pl [-n|--dry-run] [-d DIR] [-f FILE]
 device-table.pl -?|-h|--help|--version

=head1 Options

By default, F<device-table.pl> writes out the device nodes in the current
working directory. Use the directory option to write out elsewhere.

multistrap contains a default device-table file, use the file option
to override the default F</usr/share/doc/multistrap/examples/device_table.txt>

Use the dry-run option to see the commands that would be run.

Device nodes need fakeroot or another way to use root access. If
F<device-table.pl> is already being run under fakeroot or equivalent,
the existing fakeroot session will be used, alternatively,
use the no-fakeroot option to drop the internal fakeroot usage.

Note that fakeroot does not support changing the actual ownerships,
for that, run the final packing into a tarball under fakeroot as well,
or use C<sudo> when running F<device-table.pl>

=head1 Device table format

Device table files are tab separated value files (TSV). All lines in the
device table must have exactly 10 entries, each separated by a single
tab, except comments - which must start with #

Device table entries take the form of:

 <name> <type> <mode> <uid> <gid> <major> <minor> <start> <inc> <count>

where name is the file name, type can be one of: 

 f A regular file
 d Directory
 s symlink
 h hardlink
 c Character special device file
 b Block special device file
 p Fifo (named pipe)

symlinks and hardlinks are extensions to the device table, just for
F<device-table.pl>, other device table parsers might not handle these
types. The first field of the symlink command is the existing target of
the symlink, the third field is the full path of the symlink itself.
e.g.

 /proc/self/fd/0 s /dev/stdin - - - - - - -

See http://wiki.debian.org/DeviceTableScripting

=cut
