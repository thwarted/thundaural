#!/usr/bin/perl

package Logger;

use File::Basename;

my $bin_logger = '/usr/bin/logger';
my $SELFSHORT = File::Basename::basename($0);

sub logger {
	my $msg = shift;
	my $from = shift;
	if (!$from) { $from = "server"; }
	my($package, $filename, $line) = caller;
	#my $tag = $SELFSHORT;
	$filename = File::Basename::basename($filename);
	my $tag = "$filename:$line";
	$tag .= "[$$]";
	my $x = `$bin_logger -t "$tag" -- '$msg'`;
	#printf STDERR "%20s:%-5d: (%21s) %s\n", $filename, $line, $from, $msg;
}

1;

