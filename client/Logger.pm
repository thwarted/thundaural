#!/usr/bin/perl

package Logger;

use File::Basename;

my $dest = 1;

foreach my $a (@ARGV) {
        if ($a =~ m/^--stderr$/) {
		$dest = 1;
                next;
        }
}

my $bin_logger = '/usr/bin/logger';

sub logger {
        my($package, $filename, $line) = caller(0);
        my(undef, undef, undef, $subroutine) = caller(1);
	$subroutine = $package if (!$subroutine);
        my $prefix = "$subroutine($line)";
        my $format = shift;
        $msg = sprintf($format, @_);
	if ($dest == 0) {
		$prefix .= "[$$]";
		my $x = `$bin_logger -t "$prefix" -- '$msg'`;
	} elsif ($dest == 1) {
        	printf STDERR "\%s: \%s\n", $prefix, $msg;
	}
}

1;

