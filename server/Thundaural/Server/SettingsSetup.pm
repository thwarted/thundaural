#!/usr/bin/perl

# $Header: /home/cvs/thundaural/server/Thundaural/Server/SettingsSetup.pm,v 1.7 2004/06/10 06:04:11 jukebox Exp $

package Thundaural::Server::SettingsSetup;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($_devices $_defaultplaydevice $_progs $_cmds $_vars);

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Getopt::Long;

my @configfiles = qw( 
    /etc/thundaural/server.conf
    ../thundaural-server.conf
    ./thundaural-server.conf
);

our %devorder = ();
our $_devices = undef;
our $_defaultplaydevice;
our $_progs = {};
our $_cmds = {};
our $_vars = {
    storagedir=>'', 
    homedir=>'', 
    dbfile=>'', 
    listenport=>'', 
    listenhost=>'', 
    foreground=>0,
    pausebetween=>4,
    convert=>0,
    createdb=>0,
    };

my %options = (
    'more-help'=>\&usage,
    'config=s'=>\&load_config,
    'prog=s'=>\&set_prog,
    'cmd=s'=>\&set_cmd,
    'device=s'=>\&set_device,
    'storagedir=s'=>\($_vars->{storagedir}),
    'homedir=s'=>\($_vars->{homedir}),
    'dbfile=s'=>\($_vars->{dbfile}),
    'createdb'=>\($_vars->{createdb}),
    'pausebetween=i'=>\($_vars->{pausebetween}),
    'listenport=i'=>\($_vars->{listenport}),
    'listenhost=s'=>\($_vars->{listenhost}),
    'foreground|f'=>\($_vars->{foreground}),
    'log=s'=>\($_vars->{logto}),
    'dumpconf'=>\&dumpconf,
    'convert=s'=>\($_vars->{convert}),
    'convert-help'=>\&convert_help,
);
my %not_allowed_in_configfile = (convert=>1, 'convert-help'=>1);

sub usage {
    my $cfgs = join("\n    ", @configfiles);
    print <<"EOF";
$0 <option> ...
  --help               program specific help
  --more-help          additional, global options

  --config <file>      read more options from <file>
  --device <s>         define a device
  --prog <s>           specify a program location
  --cmd <s>            specify a support command (with arguments)
  --storagedir <dir>   specify the storage directory
  --dbfile <sfile>     the database file
  --createdb           write the initial database file and exit
  --listenhost         the address to listen on
  --listenport         the port to listen on
  --pausebetween <n>   the number of seconds to pause between songs

  --dumpconf          *dump config on stdout and exit (debugging)
  --foreground         don't fork; avoid daemonization
  --log <x>            log to <x>, where <x> can be a file path, the string
                       "syslog" or the string "stderr"

  --convert <c>      **invoke converter <c>
  --convert-help     **show help on the convert options (outputs lots of text)

  <file> - path to a regular file
  <dir> - path to a directory
  <sfile> - relative to the storage dir unless it starts with a /
  <s> - a string of a particular format based on context (see docs)

All options (except **) can be read from a configuration file.  One 
option per line.  Options are the same as arguments, but without the 
leading double dash.  Later options override earlier ones.  When 
reading a configuration file, its contents are inserted into the list 
of options at that point.  The following config files are read in,
if they exist, before command line options are read:

    $cfgs

* if specified in a configuration file, will keep the program from
starting up.  Only operates for options up until that option appears,
that is, the only plain --dumpconf makes sense is last after all
configuration files have been read and all command line options.

** Can not be specified in a configuration file.
EOF
    exit;
}

sub dumpconf {
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 1;
    print Dumper($_devices);
    print Dumper($_progs);
    print Dumper($_cmds);
    print Dumper($_vars);
    exit;
}

# we get a little tricky here
# I really like the interface to Getopt::Long over some of the other Getopt
# modules, but it doesn't seem to be able to read from a config file, and I 
# can't seem to find many other modules that do both in a unified fashion.  
# So we solve the problem by loading up the contents of the config file as 
# command line arguments that have a lower precedence than the options 
# specified (by unshifting and putting them BEFORE).  This has the added
# advantage of enforcing the same format for the config file and the command 
# line arguments
foreach my $c (@configfiles) {
    my @newargs = &read_configfile($c);
    unshift @ARGV, @newargs if (@newargs);
}

&usage unless GetOptions(%options);

# dbfile is relative to storagedir
if ($_vars->{dbfile} !~ m/^\//) {
    $_vars->{dbfile} = sprintf('%s/%s', $_vars->{storagedir}, $_vars->{dbfile});
}

sub read_configfile {
    # can't use die here , we'll called from a use/require block (which is part of BEGIN)
    # die will propagate an error back up the callstack
    my $configfile = shift;
    if (open(CONF, "<$configfile")) {
        my $lines = 0;
        my @newargs = ();
        while(<CONF>) {
            $lines++;
            chomp;
            s/\s*#.*$//g; 
            s/^\s+//g; 
            s/\s+$//g; 
            next if (m/^\s*$/);
            my ($k, undef, $v) = m/^(\w+)(\s+(.*))$/;
            if ($k) {
                if ($not_allowed_in_configfile{$k}) {
                    print STDERR "$0: \"$k\" found in $configfile, but can only be specified on the command line.\n";
                    exit 1;
                } else {
                    push(@newargs, "--$k");
                    push(@newargs, $v) if ($v);
                    next;
                }
            }
            print STDERR "$0: line $lines of $configfile is unparsable\n";
            exit 1;
        }
        close(CONF);
        return @newargs;
    }
}

sub load_config {
    my $opt = shift;
    my $value = shift;

    # tricky -- thankfully Getopt::Long eats up @ARGV
    # so we can just add more stuff at the begining
    # and it will consume that also :)
    my @x = &read_configfile($value);
    unshift(@ARGV, @x) if (@x);
}

sub set_prog {
    my $opt = shift;
    my $value = shift;

    my($p, $path) = $value =~ m/^(\w+):(.+)$/;
    die("$0: $path is not executable\n")
    unless (-x $path);
    $_progs->{$p} = $path;
}

sub set_cmd {
    my $opt = shift;
    my $value = shift;

    my($p, $path) = $value =~ m/^(\w+):(.+)$/;
    # cmds are relative to homedir
    if ($path !~ m/^\//) {
        $path = sprintf('%s/%s', $_vars->{homedir}, $path);
    }
    $_cmds->{$p} = $path;
}

sub set_device {
    my $opt = shift;
    my $value = shift;

    my @x = split(/:/, $value);
    my $devname = shift @x;
    my $v = {};
    while (@x) {
        my $x = shift @x;
        my($type, $dev) = $x =~ m/^(\w+)=(.+)$/;
        if ($type =~ m/^(read|play)$/) {
            $v->{_order} = ++$devorder{$type};
        }
        if (! $_defaultplaydevice && $type eq 'play') {
            $_defaultplaydevice = $devname;
        }
        $v->{$type} = $dev;
    }
    $_devices->{$devname} = $v;
}

sub convert_help {

print <<"EOF";

Thundaural normally does certain updates to its data structures automatically.
Some conversions and updates are optional or risky and should be invoked
manually.  Invoke a conversion manually by using the --convert option:

$0 --convert <conversion>:optionA[=x];optionB[=y];...

Note that you may need to escape the argument if you specify multiple options 
to escape the semicolons.

The allowable conversions are:
----------------------------------------------------------------------
  tracknumtags
     Originally, the ripper script did not store the track number in the meta
     data of the Vorbis encoded file, and the track number was not part of
     the filename.  This conversion reads the track listing from the database,
     retags the .ogg files with the track numbers and renames them to contain
     the track number (for the sake of completeness).  This conversion is
     entirely optional.  It is risky only if you've hand edited your
     Thundaural SQLite database to add tracks that were not ripped by
     the Thundaural CD ripper script (if you've only added albums to the
     system using either client/interface.pl, server/server.pl or 
     server/ripper.pl, it should be okay to run this conversion.
     
     Recognized options are:

        albums=<x>[,<x>...]
            Only convert tracks on the specified albums (by albumid)

        loose
            By default, this conversion will only manipulate ogg files that 
        were generated by the Thundaural ripper script.  Unfortuantely, 
        older versions of the script didn't tag the file with that 
        information, making it difficult to determine if the ripper script
        was responsible for that file.  Setting loose=1 overrides that 
        detection, and will force an update to the file even if it doesn't
        look like the Thundaural ripper script generated the file.

        limit=<number>
            Retag and rename at most <number> files.  You can use this to work
        on the database incrementally to ensure that everything is working
        alright.

        pause=<seconds>
            Pause for <seconds> seconds between retagging and renaming each 
        file.

        skipiflooksdone
            If the filename looks like it has the track number already in it,
        skip processing that file outright.  Used in conjunction with 
        limit to skip files processed during previous runs.

        dryrun
            don't actually change anything, just print out what would be done.

     invoke this conversion like this:
$0 --convert 'tracknumtags:loose;limit=5;pause=1;skipiflooksdone;albums=3,5'

You may want to make a backup copy of your storagedir ($_vars->{storagedir}) 
before performing this.  Use the dryrun=1 option to make sure things will 
happen like they should.  This conversion will also add CDINDEXID, CDDBID, 
and METASOURCE tags to the file if these values exist in the database for the 
album this track came from, and rename the files to have fields in the name 
delimited by double colons, rather than hyphens (I think double colons are 
rarer in artist, album and track names than a hyphen, it's also not a shell
or regular expression metacharacter), in order to improve future matching 
on the fields in the name (if necessary, which should be rare, but you never 
know).
----------------------------------------------------------------------
EOF
    
    exit;
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

