#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/Settings.pm,v 1.3 2004/05/31 08:26:43 jukebox Exp $

package Thundaural::Server::Settings;

use strict;
use warnings;
use Data::Dumper;

use Thundaural::Server::SettingsSetup qw($_devices $_defaultplaydevice $_progs $_cmds $_vars);

if (!defined($_defaultplaydevice) 
 || ref($_devices->{$_defaultplaydevice}) ne 'HASH' 
 || !($_devices->{$_defaultplaydevice}->{_order}) ) {
	die("$0: no default device defined, some error has occured\n");
}

sub foreground {
	return $_vars->{foreground};
}

sub storagedir {
	return $_vars->{storagedir};
}

sub listenport {
	return $_vars->{listenport};
}

sub listenhost {
	return $_vars->{listenhost};
}

sub dbfile {
	return $_vars->{dbfile};
}

sub default_play_device {
	return $_defaultplaydevice;
}

sub pause_between_songs {
	return $_vars->{pausebetween};
}

sub logto {
	return $_vars->{logto};
}

sub program {
	my $s = shift;
	return $_progs->{$s};
}

sub convert {
	my $s = shift;
	return $_vars->{convert};
}

sub command($) {
	my $label = shift;

	if (exists($_cmds->{$label})) {
		my $x = $_cmds->{$label};
		if ($x =~ m/\$\{PROGOPTS\}/) {
			my $n = '';
			foreach my $y (keys %{$_progs}) {
				$n .= sprintf('--prog %s:%s ', $y, $_progs->{$y});
			}
			$x =~ s/\$\{PROGOPTS\}/$n/g;
		}
		return $x;
	}
	return undef;
}

sub get($$) {
	my $l1 = shift;
	my $l2 = shift;

	if (exists($_devices->{$l1})) {
		if (exists($_devices->{$l1}->{$l2})) {
			return $_devices->{$l1}->{$l2};
		}
	}
	return undef;
}

sub get_of_type($) {
	my $type = shift;

	my @ret = ();
	foreach my $k (keys %{$_devices}) {
		my %x = %{$_devices->{$k}};
		foreach my $v1 (keys %x) {
			if ((!$type) || ($type && $type eq $v1)) {
				push(@ret, {devicename=>$k, type=>$v1});
			}
		}
	}
	return [ sort { 
			$_devices->{$a->{devicename}}->{_order} 
			cmp 
			$_devices->{$b->{devicename}}->{_order} 
		} @ret ];
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
