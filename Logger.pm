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

