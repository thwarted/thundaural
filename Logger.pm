#!/usr/bin/perl

package Logger;

use File::Basename;

my $bin_logger = '/usr/bin/logger';
my $SELFSHORT = File::Basename::basename($0);

sub logger {
	my($package, $filename, $line) = caller(0);
	my(undef, undef, undef, $subroutine) = caller(1);
	#my $prefix = "$subroutine ($filename:$line)";
	my $prefix = "$subroutine($line)";
	my $format = shift;
	$msg = sprintf($format, @_);
	printf STDERR "\%35s: \%s\n", $prefix, $msg;

	#my($package, $filename, $line) = caller;
	#my $tag = $SELFSHORT;
	#my $tag = "$filename:$line";
	#$tag .= "[$$]";
	#my $x = `$bin_logger -t "$tag" -- '$msg'`;
	#printf STDERR "%20s:%-5d: (%21s) %s\n", $filename, $line, $from, $msg;
}

1;
