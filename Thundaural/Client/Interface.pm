#!/usr/bin/perl

# $Header$

package Thundaural::Client::Interface;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use IO::Socket::INET;

use Thundaural::Logger qw(logger);
use Thundaural::Client::Album;

my $PROTOCOL_VERSION = '4';

sub new {
    my $class = shift;
    my $proto = ref($class) || $class;
    my %o = @_;

    my $this = {};
    bless $this, $proto;

    $this->{server} = $o{host} || 'jukebox';
    $this->{port} = $o{port} || 9000;
    $this->{clientlabel} = 'newclient';

    $this->{_albums} = {lastupdate=>0, list=>{}};
    $this->{_coverartcached} = {};

    $this->{status} = {};
    $this->{statuslastupdate} = 0;
    $this->{status_wait} = 5;
    $this->{random} = {};
    $this->{randomlastupdate} = 0;
    $this->{random_wait} = 120;
    $this->{queuedon} = {};
    $this->{queuedonlastupdate} = 0;
    $this->{queuedon_wait} = 120;
    $this->{lasttrackref} = '';
    $this->{stats} = {};
    $this->{statslastupdate} = 0;
    $this->{stats_wait} = 20;

    $this->{deviceslastupdate} = 0;
    $this->{devices_wait} = 600;

    $this->_ensure_connect();
    $this->_clear_input();

    return $this;
}

sub _albums_populate {
    my $this = shift;

    return if (scalar %{$this->{_albums}->{list}} && $this->{_albums}->{lastupdate} + 30 > time());

    my $x = $this->getlist('albums');
    if (ref($x) eq 'ARRAY') {
        foreach my $al (@$x) {
            $this->{_albums}->{list}->{$al->{albumid}} = $al;
        }
        $this->{_albums}->{sorted_performer} = $this->_sort_by('sortname', 'name');
    } else {
        $this->{_albums}->{list} = {};
    }
    $this->{_albums}->{lastupdate} = time();

    #$this->_precache_coverart();
}

sub _sort_by {
    my $this = shift;
    my $how = shift;
    my $how2 = shift;

    if ($how2) {
        return [ sort { ($this->{_albums}->{list}->{$a}->{$how}.' '.$this->{_albums}->{list}->{$a}->{$how2} )
                         cmp
                        ($this->{_albums}->{list}->{$b}->{$how}.' '.$this->{_albums}->{list}->{$b}->{$how2} )
                      } keys %{$this->{_albums}->{list} } 
               ];

    }

    return [ sort { $this->{albums}->{$a}->{$how} cmp $this->{albums}->{$b}->{$how} } keys %{$this->{albums}->{list} } ];
}

sub albums {
    my $this = shift;
    my %o = @_;
    my $offset = $o{offset};
    my $count = $o{count};

    $this->_albums_populate();
    my @ax = @{$this->{_albums}->{sorted_performer}};
    @ax = @ax[$offset .. ($offset+$count-1)];
    my @ret = ();
    foreach my $a (@ax) {
        my $i = $this->{_albums}->{list}->{$a};
        my $albumobj = new Thundaural::Client::Album(info=>$i, server=>$this, albumid=>$i->{albumid});
        push(@ret, $albumobj);
    }
    return \@ret;
}

sub albums_count {
    my $this = shift;
    return scalar keys %{$this->{_albums}->{list}};
}

sub _precache_coverart {
    my $this = shift;

    foreach $a (keys %{$this->{_albums}->{list}}) {
        $a = $this->{_albums}->{list}->{$a};
        $a = new Thundaural::Client::Album(info=>$a, server=>$this, albumid=>$a->{albumid});
        my $x = $a->coverartfile();
        print "precached $x\n";
    }
}

sub coverart {
    my $this = shift;
    my %o = @_;
    my $albumid = $o{albumid};;
    my $outputfile = $o{outputfile};

    #return '/dfdf' if (rand(50) > 25);

    my $bytes = $this->_do_cmd("coverart $albumid");
    if (!$bytes || $bytes =~ m/^\d{3}$/) {
        logger('no data received for cover art');
        $bytes = '';
        #return undef;
    }

    #logger('coverart for %d is %d bytes', $albumid, length($bytes));

    open(F, ">$outputfile");
    print F $bytes;
    close(F);

    return $outputfile;
}

sub _ensure_connect {
    my $this = shift;

    if (!$this->{ihn} || !$this->{ihn}->connected()) {
        my $try = 0;
        eval { $this->{ihn}->shutdown(2); };
        OPENCONNECTION:
        while(1) {
            TRYCONNECT:
            while(1) {
                $try++;
                $this->{ihn} = new IO::Socket::INET(PeerAddr=>$this->{server}, PeerPort=>$this->{port}, proto=>'tcp');
                if ($this->{ihn} && $this->{ihn}->connected()) {
                    if ($try > 1 && ref($this->{recoveredfunc}) eq 'CODE') {
                        my $f = $this->{recoveredfunc};
                        &$f();
                    }
                    last TRYCONNECT;
                }
                logger("unable to connect to %s:%s", $this->{server}, $this->{port});
                if (ref($this->{errorfunc}) eq 'CODE') {
                    my $f = $this->{errorfunc};
                    &$f(sprintf("jukebox server (%s:%s)\nis not responding\n\nPlease wait...\n\ntry $try",
                        $this->{server}, $this->{port}));
                }
                if (ref($this->{idlefunc}) eq 'CODE') {
                    my $f = $this->{idlefunc};
                    &$f();
                }
            }
            my $h = $this->{ihn};
            my $x;

            # wait for the server to respond
            print $h "noop connectionsync-".time()."\n";
            $x = <$h>;
            next OPENCONNECTION if (!defined($x));

            # verify protocol version
            print $h "version\n";
            $x = <$h>;
            next OPENCONNECTION if (!defined($x));
            ($x) = $x =~ m/^200 version (.+)/;
            die("unable to determine server's protocol version\n")
                unless (defined($x));
            die("client/server protocol version mismatch ".
                "(server reports $x, looking for $PROTOCOL_VERSION)\n")
                unless ($x eq $PROTOCOL_VERSION);

            # set our client name -- do auth here in the future
            my $me = `/bin/hostname`; chomp $me;
            print $h sprintf('name %s(%d,%s)%s', $me, $$, $this->{clientlabel}, "\n");
            $x = <$h>; # dump response line
            last if defined($x);
        }
    }
    return $this->{ihn};

}

sub _clear_input {
    my $this = shift;
    my $tail = shift || '';
    $tail .= '.' if ($tail);
    $tail .= sprintf('%d.%d', time(), int(rand(999)));

    my $h = $this->_ensure_connect();
    print $h "noop $tail\n";
    my $i;
    do {
        $i = <$h>;
        if (!$i) {
            die("error when connecting, disconnected half way through, aborting");
        }
        chomp $i;
    } while($i !~ m/200 noop $tail/);
}

sub _do_cmd {
    my $this = shift;
    my $cmd = join(' ', @_);

    my($input, $rescode, $more, @x, $rl, $h, $keylist, @keys, @results, $k, $v);

    RECONNECT:
    while (1) {
        $h = $this->_ensure_connect();
        logger(">> $cmd");
        print $h "$cmd\n";
        $input = <$h>;
        next if (!defined($input));
        chomp $input;
        logger("<< $input");
        #print "input = \"$input\"\n";
        ($rescode, $more) = $input =~ m/^(\d{3}) (count|(\d+) bytes follow)?/;
        $rescode = 0 if !defined($rescode);
        if ($rescode == 202) { # binary data
            my($size) = $more =~ m/^(\d+) bytes/;
            if (!$size) {
                # verify that there is no data
                $input = <$h>;
                next RECONNECT if (!defined($input));
                chomp $input;
                next RECONNECT if ($input !~ m/^\.$/);
                return '';
            }
            my $bytes = '';
            while(length($bytes) < $size) {
                my $i = '';
                my $x = read($h, $i, 1);
                next RECONNECT if (!defined($x) || $x != 1);
                $bytes .= $i;
            }
            $input = <$h>; 
            next RECONNECT if (!defined($input));
            chomp $input;
            next RECONNECT if ($input !~ m/^\.$/);
            return $bytes;
        }
        if (200 <= $rescode && $rescode <= 299) {
            # 202 has already been handled, we're really handling 200 and 201 here
            last RECONNECT if (!defined($more));
            ($keylist) = $input =~ m/\(([^()]+)\)/;
            @keys = split(/\s+/, $keylist);
            @results = ();
            MORE:
            while (1) {
                $input = <$h>;
                next RECONNECT if (!defined($input));
                chomp $input;
                #print "input = \"$input\"\n";
                last MORE if ($input =~ m/^\.$/);
                @x = split(/\t/, $input);
                $rl = {};
                foreach $k (@keys) {
                    $v = shift @x;
                    $rl->{$k} = $v;
                }
                push(@results, $rl);
            }
            return \@results;
        } else {
            return $rescode;
        }
    }
    return $rescode;
}

sub getlist($) {
    my $this = shift;

    return $this->_do_cmd(@_);
}

sub _populate_devices {
    my $this = shift;
    return if ($this->{deviceslastupdate}+$this->{devices_wait} > time());
    my $d = $this->_do_cmd('devices');
    if (ref($d) eq 'ARRAY') {
        $this->{devices} = {};
        foreach my $x (@$d) {
            my $dt = $x->{type};
            if (!defined($this->{devices}->{$dt})) {
                $this->{devices}->{$dt} = [];
            }
            push(@{$this->{devices}->{$dt}}, $x);
        }
        $this->{deviceslastupdate} = time();
    } else {
        Logger::logger("unable to get device list from server, result was $d");
        $this->{devices} = {};
    }
}

sub devices {
    my $this = shift;
    my $type = shift;

    $this->_populate_devices();
    return [] if (!$type);
    my @ret = ();
    foreach my $d (@{$this->{devices}->{$type}}) {
        my $dn = $d->{devicename};
        push(@ret, $dn);
    }
    return [@ret];
}

sub _populate_random {
    my $this = shift; 
    return if ($this->{randomlastupdate}+$this->{random_wait} > time());
    my $st = $this->_do_cmd('randomize');
    if (ref($st) eq 'ARRAY') {
        $this->{random} = {};
        foreach my $x (@$st) {
            my $dn = $x->{devicename};
            $this->{random}->{$dn} = $x->{endtime};
        }
        $this->{randomlastupdate} = time();
    } else {
        logger("unable to get randomization, result was $st");
        $this->{random} = {};
    }
}   

sub random_play {
    my $this = shift;
    my %o = @_;
    my $minutes = $o{duration};
    my $devicename = $o{device};

    return 0 if (!$devicename);
    return 0 if ($minutes !~ m/^\d+$/);
    $minutes += 0;

    $this->{random} = {};
    $this->{randomlastupdate} = -10;
    $this->_do_cmd("randomize $devicename for $minutes");
}

sub will_random_play_until {
    my $this = shift;
    my $dn = shift;

    $this->_populate_random();
    return (exists($this->{random}->{$dn}) ? $this->{random}->{$dn} : undef);
}

sub _populate_status {
    my $this = shift;
    return if ($this->{statuslastupdate}+$this->{status_wait} > time());
    my $st = $this->_do_cmd('status');
    if (ref($st) eq 'ARRAY') {
        $this->{status} = {};
        my $ltr = '';
        foreach my $x (@$st) {
            my $dn = $x->{devicename};
            $this->{status}->{$dn} = $x;
            $ltr .= "-".(defined($x->{trackref}) ? $x->{trackref} : 'none');
        }
        $this->{statuslastupdate} = time();
        if ($ltr ne $this->{lasttrackref}) {
            $this->{queuedonlastupdate} = 0;
        }
        $this->{lasttrackref} = $ltr;
    } else {
        logger("unable to get status, result was $st");
        $this->{status} = {};
    }
}

sub playing_on {
    my $this = shift;
    my $channel = shift;

    return 
    new Thundaural::Client::Track(info=>{
    devicename=>'main',
    type=>'play',
    state=>'idle',
    volume=>67, #int(((time() - $main::starttime) % 123) /123 * 100),
    trackref=>'6/1',
    performer=>'The Beatles',
    name=>"Sgt. Pepper's Lonely Hearts Club Band",
    popularity=>0.055413,
    rank=>8,
    length=>123,
    trackid=>39,
    started=>$main::starttime,
    current=>((time() - $main::starttime) % 123),
    percentage=>((time() - $main::starttime) % 123) /123
    });

    $this->_populate_status();
    if (!$channel) {
        return $this->{status};
    }
    my $x = $this->{status}->{$channel};
    if (ref($x) eq 'HASH' && $x->{trackref}) {
        $x = new Thundaural::Client::Track(info=>$x);
    } else {
        $x = undef;
    }
    return $x;
}

sub volume {
    my $this = shift;
    my $channel = shift;

    $this->_populate_status();
    if (!$channel) {
        croak("no channel passed to volume");
        return undef;
    }
    my $vol = $this->{status}->{$channel}->{volume};
    $vol += 0;
    return $vol;
}

sub _populate_queued_on {
    my $this = shift;
    return if ($this->{queuedonlastupdate}+$this->{queuedon_wait} > time());
    my $qo = $this->_do_cmd('queued');
    $this->{queuedon} = {};
    if (ref($qo) eq 'ARRAY') {
        foreach my $trkinfo (@$qo) {
            my $dn = $trkinfo->{devicename};
            if (!exists($this->{queuedon}->{$dn})) {
                $this->{queuedon}->{$dn} = [];
            }
            print Dumper($trkinfo);
            my $trk = new Thundaural::Client::Track(info=>$trkinfo);
            push(@{$this->{queuedon}->{$dn}}, $trk);
        }
        $this->{queuedonlastupdate} = time();
    } else {
        logger("unable to get queued track list, result was $qo");
    }
}

sub queued_on {
    my $this = shift;
    my $channel = shift;

    return [
        $this->playing_on(), $this->playing_on(), $this->playing_on(), $this->playing_on(), $this->playing_on(),
        $this->playing_on(), $this->playing_on(), $this->playing_on(), $this->playing_on(), $this->playing_on()
    ];

    croak("must pass channel name to queued_on") if (!$channel);
    $this->_populate_queued_on();
    my $x = $this->{queuedon}->{$channel};
    if (ref($x) ne 'ARRAY') {
        $x = [];
    }
    return [@$x];
}

sub _populate_stats {
    my $this = shift;
    return if ($this->{statslastupdate}+$this->{stats_wait} > time());
    logger("populating STATS");
    my $x = $this->_do_cmd('stats');
    if (ref($x) eq 'ARRAY') {
        $this->{stats} = {};
        foreach my $l (@$x) {
            $this->{stats}->{$l->{key}} = $l->{value};
        }
        $this->{statslastupdate} = time();
    } else {
        Logger::logger("unable to get stat info from server, result was $x");
        $this->{stats} = {};
    }
}

sub stats {
    my $this = shift;

    $this->_populate_stats();
    return {%{$this->{stats}}}; # make a copy for the caller
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

