#!/usr/bin/perl

package Logger;

use Sys::Syslog;
use File::Basename;

my $dest;
BEGIN {
	$dest = 0;

	foreach my $a (@ARGV) {
		if ($a =~ m/^--syslog$/) {
			$dest = 0;
			next;
		}
        	if ($a =~ m/^--stderr$/) {
			$dest = 1;
                	next;
        	}
	}
	
	if ($dest == 0) {
		my $program = File::Basename::basename($0);
		openlog($program, 'cons,pid', 'user');
	}
}

END {
	closelog();
}

sub logger {
        my($package, $filename, $line) = caller(0);
        my(undef, undef, undef, $subroutine) = caller(1);
	$subroutine = $package if (!$subroutine);
        my $prefix = "$subroutine($line)";
        my $format = shift;
        $msg = sprintf($format, @_);
	if ($dest == 0) {
		syslog('info', '%s: %s', $prefix, $msg);
	} elsif ($dest == 1) {
        	printf STDERR "\%s: \%s\n", $prefix, $msg;
	}
}

1;

#    Thundaural Jukebox
#    Copyright (C) 2003-2004  Andrew A. Bakun
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
