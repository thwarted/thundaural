#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Logger.pm,v 1.2 2004/05/30 09:15:52 jukebox Exp $

package Thundaural::Logger;

use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(logger);

use Sys::Syslog;
use File::Basename;
use IO::Handle;

my $FH;
my $mode;
my $configured = 0;

sub init {
    $mode = shift;
    if (!$configured) {
        if (defined($mode) && $mode) {
            if ($mode eq 'syslog') {
                _open_syslog();
            } elsif ($mode eq 'stderr') {
                _open_stderr();
            } else {
                _open_file($mode);
            }
        } else {
            _open_stderr();
        }
        $configured++;
    }
}

sub _open_syslog {
    my $program = File::Basename::basename($0);
    openlog($program, 'cons,pid', 'user');
}

sub _open_stderr {
    $FH = *STDERR;
    $mode = 'file';
}

sub _open_file {
    my $file = shift;
    open($FH, ">>$file") || die("unable to open $file for writing\n");
    $mode = 'file';
}

sub logger {
        my($package, $filename, $line) = caller(0);
        my(undef, undef, undef, $subroutine) = caller(1);
    if ($subroutine eq '(eval)') {
            (undef, undef, undef, $subroutine) = caller(2);
    }
    $subroutine = $package if (!$subroutine);
        my $prefix = "$subroutine($line)";
        my $format = shift;
        my $msg = sprintf($format, @_);
    if ($mode eq 'file') {
        printf $FH "\%s: \%s\n", $prefix, $msg;
    } else {
        syslog('info', '%s: %s', $prefix, $msg);
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
