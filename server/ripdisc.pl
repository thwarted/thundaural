#!/usr/bin/perl

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use File::Glob ':glob';
use Storable qw(freeze thaw);

if (defined($ARGV[0]) && $ARGV[0] eq '--passthru') {
    shift @ARGV;
    &passthru(@ARGV);
    exit;
}

BEGIN {
    select STDERR; $| = 1; select STDOUT; $| = 1; 
    if (defined($ARGV[0]) && $ARGV[0] ne '--passthru') {
        # redirect STDERR to STDOUT -- avoid having to 
        # invoke a shell in the caller to do redirection
        open(STDERR, '>&=STDOUT');

        setpgrp(0, $$) or die("setpgrp failed: $!\n");
    }
}

$SIG{__WARN__} = sub { cluck(@_); };

# order is important here.  They'll be queried in the order specified
# and the first one to succeed will be used.
my $cdinfo_modules = ['MusicBrainzRemote', 'FreeDB'];

eval "use Thundaural::Server::Settings;"; # this is to get the quick --passthru option to work above

my $sx = {};
my $taversion = Thundaural::Server::Settings::audio_ripper_version();
my $accepteddbversion = 5;
my $bin_getcoverart = './getcoverart.php';
my $preripped = 0;

use Thundaural::Util;
use DBI;
my $dbh;

&parse_command_line(@ARGV);
&verify_settings;

# it would be really cool to allow manually creating 
# a metadata file but read the audio from a physical CD
if ($sx->{cddevice} && !$sx->{infofile}) {
    &cleanup;
    my $cdinfo = &get_audiocd_info;

    if (!defined($cdinfo)) {
        &dumpstatus("idle", "unable to get album information from disc");
        exit;
    }
    &dump_discinfo($cdinfo, '1lookup');

    # do we already have this album ?
    if (&already_have_album($cdinfo)) {
        &dumpstatus('idle', sprintf('already have album %s - %s', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}));
        exit;
    }

    $SIG{HUP} = \&abortus;
    $SIG{TERM} = \&abortus;

    # get the coverart
    my($catemp, $coverartfile) = &get_cover_art($cdinfo);
    $cdinfo->{coverarttemp} = $catemp;
    $cdinfo->{coverartfile} = $coverartfile;
    &dump_discinfo($cdinfo, '2artwork');

    my $ripstart = time();
    &rip_tracks($cdinfo);
    $cdinfo->{riptime} = time() - $ripstart;
    &dump_discinfo($cdinfo, '3ripped');

    my $failed = &add_album($cdinfo);
    if ($failed) {
        &dumpstatus('idle', sprintf('ripping "%s - %s" failed with error "%s"', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}, $failed));
    } else {
        &dumpstatus('idle', sprintf('ripping "%s - %s" successful', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}));
    }
}

if ($sx->{infofile} && !$sx->{cddevice}) {
    $preripped = 1;
    $sx->{cddevice} = "local";
    if (!open(X, "<".$sx->{infofile})) {
        die("unable to read ".$sx->{infofile}.": $!\n");
    }
    my $pv = join('', <X>); 
    close(X);
    my $cdinfo = eval "return my $pv;";
    if ($@) {
        die("unable to read ".$sx->{infofile}.": $@\n");
    }
    print Dumper($cdinfo);

    # do we already have this album ?
    # this will most likely not do anything, because preripped
    # tracks won't have cdindex or cddbid info, they didn't
    # necessarily come from a physical album
    if (&already_have_album($cdinfo)) {
        &dumpstatus('idle', sprintf('already have album %s - %s', $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname}));
        exit;
    }

    my $cadir = sprintf('coverart/%s', &get_sort_dir($cdinfo->{album}->{performersort}));
    mkdir(sprintf('%s/coverart', $sx->{storagedir}), 0777);
    mkdir(sprintf('%s/%s', $sx->{storagedir}, $cadir), 0777);
    # assume the extension is correct here
    my($ext) = $cdinfo->{coverarttemp} =~ m/\.(\w+)$/;
    $cdinfo->{coverartfile} = sprintf('%s/%s - %s - %d - coverart.%s', 
            $cadir,
            $cdinfo->{album}->{performer}, 
            $cdinfo->{album}->{albumname},
            $$, # some level of uniqueness
            $ext
    );
    $cdinfo->{riptime} = 0;
    foreach my $track (@{$cdinfo->{tracks}}) {
        my $artist = $track->{performer};
        if ($cdinfo->{album}->{performer} =~ m/various artists/i) {
            $artist = "(Various Artists) $artist";
        }
        my $album = $cdinfo->{album}->{albumname};
        my $tracknum = $track->{tracknum};
        my $title = $track->{trackname};
        $track->{sortdir} = &get_sort_dir($artist);
        $track->{finalfilename} = sprintf("%s :: %s :: %02d :: %s.ogg", &unslash($artist), &unslash($album), $tracknum, &unslash($title));
    }
    my $failed = &add_album($cdinfo);
    if ($failed) {
        print "unable to add album: $failed\n";
    } else {
        print sprintf("successfully added album %s - %s\n", $cdinfo->{album}->{performer}, $cdinfo->{album}->{albumname});
    }
}

$dbh->disconnect;

sub dump_discinfo {
    my $cdinfo = shift;
    my $mode = shift;
    my $pvtemp = Thundaural::Util::mymktempname($sx->{storagedir}, $sx->{cddevice}, "discinfo-$mode.pv");
    open(X, ">$pvtemp");
    print X Dumper($cdinfo)."\n";
    close(X);
}

sub add_album {
    my $cdinfo = shift;
    my $q;

    $dbh->begin_work();

    my $trackcount = 0;
    my $undorenames = {};
    my $failed = 0;
    TRANSACTION:
    while (1) { 
        my $e;

        # add album
        my $perf = $cdinfo->{album}->{performer};
        my $perfsort = $cdinfo->{album}->{performersort};
        my $perfid;
        eval {
            $perfid = &performer_id($perf, $perfsort);
        };
        if ($@) { $failed = $@; last TRANSACTION; }
        my $q = "insert into albums 
            (albumid, performerid, name, cdindexid, cddbid, length, riptime, tracks, source)
            values 
            (NULL,    ?,           ?,    ?,         ?,      ?,      ?,       ?,      ?)";
        $q =~ s/\s+/ /g;
        my $sth = $dbh->prepare($q);
        eval {
            $sth->execute(
                $perfid,
                $cdinfo->{'album'}->{'albumname'},
                $cdinfo->{'cdindexid'},
                $cdinfo->{'cddbid'},
                $cdinfo->{'totaltime'},
                $cdinfo->{'riptime'},
                $cdinfo->{'numtracks'},
                $cdinfo->{'source'}
            );
        };
        $e = $@;
        $sth->finish;
        if ($e) { $failed = "database update: $e"; last TRANSACTION; }
        $q = "select last_insert_rowid()";
        $sth = $dbh->prepare($q);
        my $albumid;
        eval { 
            $sth->execute();
            ($albumid) = $sth->fetchrow_array();
        };
        $e = $@;
        $sth->finish;
        if ($e) { $failed = "database update: $e"; last TRANSACTION; }

        # do the cover art
        if (-s $cdinfo->{coverarttemp}) {
            my $newcafile = sprintf('%s/%s', $sx->{storagedir}, $cdinfo->{coverartfile});
            if (!(&move_file($cdinfo->{coverarttemp}, $newcafile))) {
                $failed = "renaming cover art failed: $!";
                last TRANSACTION;
            } else {
                $undorenames->{$newcafile} = $cdinfo->{coverarttemp};
                my $q = "insert into albumimages (albumid, label, preference, filename) values (?, ?, ?, ?)";
                my $sth = $dbh->prepare($q);
                eval { $sth->execute($albumid, 'front cover', 1, $cdinfo->{coverartfile}); };
                my $e = $@;
                $sth->finish;
                if ($e) {
                    $failed = "adding cover art to database: $e";
                    last TRANSACTION;
                }
            }
        }

        # add each track
        my $albumorder = 1;
        foreach my $track (@{$cdinfo->{tracks}}) {
            if (!$track->{filename} || !$track->{sortdir} ) {
                next;
            }
            if (! -e $track->{filename} && 
                ! -s $track->{filename} ) {
                #&& $track->{trackname} =~ m/data.+track/i) idiots who populate freedb put 'movies' rather than 'data track'
                next;
                # found a data track that refused to be ripped
                # don't consider this an error, just skip it
            }
            my $sortdir = $track->{sortdir};
            my $destdir = sprintf('%s/%s', $sx->{storagedir}, $sortdir);
            mkdir($destdir, 0777);
            if (!-d $destdir) {
                $failed = "creation of sortdir \"$sortdir\" failed";
                last TRANSACTION;
            }
            my $newfile = sprintf('%s/%s', $destdir, $track->{finalfilename});
            #printf STDERR "renaming\n\t%s\nto\n\t%s\n", $track->{filename}, $newfile;
            if (-e $newfile) {
                $failed = "renaming track to existing file";
                last TRANSACTION;
            }
            if (!(&move_file($track->{filename}, $newfile))) {
                $failed = "file rename failed: $!";
                last TRANSACTION;
            }
            $undorenames->{$newfile} = $track->{filename};
            my $perf = $track->{performer};
            my $perfsort = $track->{performersort};
            eval {
                $perfid = &performer_id($perf, $perfsort);
            };
            if ($@) { $failed = $@; last TRANSACTION; }
            my $q = "insert into tracks 
                    (trackid, albumid, performerid, length, name, albumorder, popularity, rank, filename, riperrors)
                 values
                     (NULL,    ?,       ?,           ?,      ?,    ?,          NULL,       NULL, ?,        NULL)";
            $q =~ s/\s+/ /g;
            my $sth = $dbh->prepare($q);
            eval {
                $sth->execute(
                    $albumid, 
                    $perfid, 
                    $track->{'length'}, 
                    $track->{trackname}, 
                    $albumorder, 
                    # filename in the database is relative to the storage dir
                    sprintf('%s/%s', $sortdir, $track->{finalfilename})
                );
            };
            $e = $@;
            $sth->finish;
            if ($e) { $failed = $e; last TRANSACTION; }
            $albumorder++;
            $trackcount++;
        }

        last TRANSACTION; # we only want to execute this loop once
    }

    if (!$trackcount && !$failed) {
        $failed = "no tracks were ripped";
    }

    if ($failed) {
        $dbh->rollback();
        foreach my $utr (keys %{$undorenames}) {
            &undo_move_file($utr, $undorenames->{$utr});
        }
        return $failed;
    } else {
        $dbh->commit();
        return 0;
    }
}

sub move_file {
    my $src = shift;
    my $dest = shift;

    if ($preripped) {
        if (open(S, "<$src")) {
            if (open(D, ">$dest")) {
                my $buf = '';
                while(read(S, $buf, 8192)) {
                    print D $buf;
                }
                close(D);
            }
            close(S);
        }
    } else {
        return rename($src, $dest);
    }
}

sub undo_move_file {
    my $src = shift;
    my $dest = shift;

    if ($preripped) {
        return unlink($src);
    } else {
        return rename $src, $dest;
    }
}

sub get_cover_art {
    my $cdinfo = shift;

    my $catemp = Thundaural::Util::mymktempname(
        $sx->{storagedir},
        $sx->{cddevice},
        sprintf('disc%s.coverart.image', $cdinfo->{cddbid})
    );

    #$coverartfile = sprintf("coverart/$sortdir/$artist - $albumtitle - $cddbid - coverart.jpg";
    my $cadir = sprintf('coverart/%s', &get_sort_dir($cdinfo->{album}->{performersort}));
    mkdir(sprintf('%s/coverart', $sx->{storagedir}), 0777);
    mkdir(sprintf('%s/%s', $sx->{storagedir}, $cadir), 0777);
    my $coverartfile = sprintf('%s/%s - %s - %s - coverart.image', 
            $cadir,
            $cdinfo->{album}->{performer}, 
            $cdinfo->{album}->{albumname},
            $cdinfo->{cddbid}
    );

    my $artist = $cdinfo->{album}->{performer};
    $artist =~ s/"//g;
    my $albumtitle = $cdinfo->{album}->{albumname};
    $albumtitle =~ s/"//g;
    my $cmd = "$bin_getcoverart \"$artist\" \"$albumtitle\" $catemp >/tmp/xx1 2>&1";
    &dumpstatus('busy', "finding cover art for \"$artist - $albumtitle\"");
    system($cmd);

    # ensure the file exists
    open(W, ">>$catemp");
    close(W);

    if (my $ext = &determine_extension($catemp)) {
        my $oldtemp = $catemp;
        $catemp =~ s/\.image$/.$ext/;
        $coverartfile =~ s/\.image$/.$ext/;
        rename $oldtemp, $catemp;
    }

    return ($catemp, $coverartfile);
}

sub determine_extension {
    my $file = shift;
    # let's not rely on an external program here, just read the magic
    # 0000000 211   P   N   G  \r  \n 032  \n  \0  \0  \0  \r   I   H   D   R
    # 0000000   G   I   F   8   9   a   $  \0   ;  \0 367  \0  \0 377 377 377
    # 0000000 377 330 377 340  \0 020   J   F   I   F  \0 001 002  \0  \0   d
    if (open(F, "<$file")) {
        my $buf = '';
        my $res = sysread(F, $buf, 16, 0);
        if ($res && $res == 16) {
            # luckily the format for all three of these can be determined 
            # from the first 16 bytes
            return 'png' if ($buf =~ m/PNG/i);
            return 'gif' if ($buf =~ m/GIF/i);
            return 'jpg' if ($buf =~ m/JFIF/i);
        }
    }
    return undef;
}

sub performer_id {
    my $perf = shift;
    my $perfsort = shift;

    my $perfid;
    if ($perfid = &performer_id_lookup($perf)) {
        return $perfid;
    }
    if ($perfid = &performer_id_add($perf, $perfsort)) {
        return $perfid;
    }
    &mydie("unable to add performer\n");
}

sub performer_id_lookup {
    my $perf = shift;
    my $e;

    my $q = "select performerid from performers where name = ? order by performerid limit 1";
    my $sth = $dbh->prepare($q);
    my $perfid;
    eval {
        $sth->execute($perf);
        ($perfid) = $sth->fetchrow_array();
    };
    $e = $@;
    $sth->finish;
    &mydie("database error $e") if ($e);
    return $perfid ? $perfid : undef;
}

sub performer_id_add {
    my $perf = shift;
    my $perfsort = shift;

    my $e;
    my $q = "insert into performers (performerid, name, sortname) values (NULL, ?, ?)";
    my $sth = $dbh->prepare($q);
    eval {
        $sth->execute($perf, $perfsort);
    };
    $e = $@;
    $sth->finish;
    &mydie("database error $e") if ($e);
    $q = "select last_insert_rowid()";
    $sth = $dbh->prepare($q);
    my $perfid;
    eval {
        $sth->execute();
        ($perfid) = $sth->fetchrow_array();
    };
    $e = $@;
    $sth->finish;
    &mydie("database error $e") if ($e);
    return $perfid ? $perfid : undef;
}

sub already_have_album {
    my $cdinfo = shift;
    my($id, $albumid, $e);

    # check cdindexid
    if (defined($id = $cdinfo->{cdindexid}) && $cdinfo->{cdindexid}) {
        my $q = "select albumid from albums where cdindexid = ? limit 1";
        my $sth = $dbh->prepare($q);
        eval {
            $sth->execute($id);
            ($albumid) = $sth->fetchrow_array();
        };
        $e = $@;
        $sth->finish;
        &mydie("database error $e") if ($e);
    }
    return $albumid if ($albumid);

    # check cddbid
    if (defined($id = $cdinfo->{cddbid}) && $cdinfo->{cddbid}) {
        my $q = "select albumid from albums where cddbid = ? limit 1";
        my $sth = $dbh->prepare($q);
        eval {
            $sth->execute($id);
            ($albumid) = $sth->fetchrow_array();
        };
        $e = $@;
        $sth->finish;
        &mydie("database error $e") if ($e);
    }
    return $albumid if ($albumid);

    return undef;
}

sub rip_tracks {
    my $cdinfo = shift;

    # determine which extractor to use
    my $ripperprg = &find_audio_ripper;

    my $tracknum = 0;
    my $totaltracks = scalar @{$cdinfo->{tracks}};
    foreach my $track (@{$cdinfo->{tracks}}) {
        $tracknum++;

        my $dorip = $ripperprg;
        $dorip =~ s/\$cddevice/$sx->{cddevice}/g;
        $dorip =~ s/\$track/$tracknum/g;

        #my $doenc = $encodeprg;
        my($doenc, $outfile, $finalfile, $progressre, $inputsep) = &find_audio_encoder($cdinfo, $track, $tracknum);

        my $tracklen = $track->{sectors} / 75; # in seconds
        my $artist = $track->{performer};
        my $title = $track->{trackname};

        #print "\nrunning\n\t$dorip\n\t$doenc\n";
        my $cmd = "( $dorip 2>/dev/null ) | ( $doenc 2>&1 ) |";
        print "$cmd\n";
        my $startat = time();
        open(RIP, $cmd);
        my $oldsep = $/;
        $/ = $inputsep;
        my $oldpct = 0;
        while(my $line = <RIP>) {
            if (my($pct) = $line =~ m/$progressre/) {
                $pct = int($pct);
                if ($pct ne $oldpct) {
                    my $speed = &calc_speed($tracklen, $startat, $pct);
                    &dumpstatus('ripping', '', "$tracknum/$totaltracks", $artist, $title, 0, $speed, $tracklen, '?', $startat, 0, $pct);
                    $oldpct = $pct;
                }
            }
        }
        $/ = $oldsep;
        close(RIP);
        my $runtime = time() - $startat;
        $track->{filename} = $outfile;
        $track->{sortdir} = &get_sort_dir($track->{performersort});
        #$track->{finalfilename} = sprintf("%s :: %s :: %02d :: %s.wav", &unslash($artist), &unslash($album), $tracknum, &unslash($title));
        $track->{finalfilename} = $finalfile;
    }
}

sub unslash {
    my $x = shift;
    $x =~ s!/!-!g;
    return $x;
}

sub parse_command_line {
    $sx->{output} = "text";
    my %options = (
        'help'=>\&usage,
        'output=s'=>\($sx->{output}),
        'cddevice=s'=>\($sx->{cddevice}),
        'infofile=s'=>\($sx->{infofile})
    );
    #&mydie("invoked with invalid arguments")
        exit unless GetOptions(%options);
    &mydie("'storable' and 'text' are the only allowed arguments to output\n")
        if ($sx->{output} !~ m/^(storable|text)$/);

    $sx->{storagedir} = Thundaural::Server::Settings::storagedir();
    $sx->{dbfile} = Thundaural::Server::Settings::dbfile();
}

sub usage {
    print STDERR <<"EOF";
$0 <option> ...
  --help           print help message
  --output <t>     format to output status messages, "text" or 
                    "storable" (perl)
  --prog name:path set the program name to path
  --storagedir     the thundaural storage directory
  --dbfile         the thundaural database file

The following two options are mutually exclusive:
  --cddevice <d>   use cdrom device <d>, read data from physical
                    media
  --infofile <f>   read album/track info from file <f>. don't rip 
                    from physical media. the file should be 
                    generated with another, related utility and
                    should contain all the metadata and audio
                    file location information
EOF
    exit;
}

#sub set_prog {
#    my $opt = shift;
#    my $value = shift;
#                                                                                                                                                       
#    my($p, $path) = $value =~ m/^(\w+):(.+)$/;
#    &mydie("$path is not executable\n") unless (-x $path);
#    $sx->{_progs}->{$p} = $path;
#}


sub verify_settings {
    &mydie("missing --storagedir argument\n") unless ($sx->{storagedir});
    &mydie("specified storagedir (".$sx->{storagedir}.") is not an accessible directory.\n")
        unless( -d $sx->{storagedir} &&
            -r $sx->{storagedir} &&
            -w $sx->{storagedir});

    if (!$sx->{infofile}) {
        &mydie("missing --cddevice argument\n") unless ($sx->{cddevice});
        &mydie("specified cdrom device (".$sx->{cddevice}.") is not readable\n")
            unless (-r $sx->{cddevice});
        $sx->{devname} = $sx->{cddevice};
        $sx->{devname} =~ s/\W/_/g;
        $sx->{devname} =~ s/_+/_/g;
    }
    if (!$sx->{cddevice}) {
        &mydie("unable to find ".$sx->{infofile}."\n") unless (-s $sx->{infofile});
    }

    &mydie("missing --dbfile argument\n") unless ($sx->{dbfile});
    &mydie("database (".$sx->{dbfile}.") doesn't exist\n") unless (-e $sx->{dbfile});
    &mydie("database (".$sx->{dbfile}.") isn't a regular file\n") unless (-f $sx->{dbfile});
    &mydie("database (".$sx->{dbfile}.") has zero size\n") unless (-s $sx->{dbfile});

    # bind to database
    $dbh = DBI->connect("dbi:SQLite:dbname=".$sx->{dbfile},'','',{RaiseError=>1, PrintError=>0, AutoCommit=>1})
        or &mydie(sprintf('unable to bind to database: %s%s', $DBI::errstr, "\n"));

    my $q = "select value from meta where name = 'dbversion'";
    my $sth = $dbh->prepare($q);
    my $dbversion;
    eval {
        $dbversion = 0;
        $sth->execute();
        ($dbversion) = $sth->fetchrow_array();
    };
    $sth->finish;
    &mydie("database version mismatch, looking for $accepteddbversion, found $dbversion")
        unless ($dbversion == $accepteddbversion);

    #$dbh->trace(2);

}

sub get_audiocd_info {
    # get cd information
    #    import module
    #    call lookup method
    #    fail, try next module
    &dumpstatus('busy', 'reading CD info');
    foreach my $modulex (@$cdinfo_modules) {
        &dumpstatus('busy', "looking up CD info using $modulex");
        sleep 2;
        my $module = sprintf('Thundaural::Rip::Lookup::%s', $modulex);
        eval "use $module;";
        if ($@) {
            my $x = $@;
            if ($x =~ m/Can't locate .+ in/) {
                ($x) = $x =~ m!(Can't locate .+) in!;
            } else {
                chomp $x;
            }
            &dumpstatus('busy', "including $modulex: $x");
            sleep 2;
            next;
        }
        my $album;
        eval {
            my $o = new $module(cddevice=>$sx->{cddevice}, storagedir=>$sx->{storagedir});
            $album = $o->lookup();
        };
        if ($@) {
            my $x = $@;
            chomp $x;
            &dumpstatus('busy', $x);
            sleep 2;
            next;
        }
        if (ref($album) eq 'HASH') {
            &dumpstatus('busy', "$modulex succeeded");
            sleep 1;
            return $album;
        }
    }
    return undef;
}

sub find_audio_ripper {
    # in order of priority, gotta have one of these
    my @progs = qw/
        dagrab
        cdda2wav
        cdparanoia
    /;
    my $progopts = {
        dagrab=>'-d $cddevice $track -J -f -',
        cdda2wav=>'--no-infofile --device $cddevice --track $track+$track --output-format wav -',
        cdparanoia=>'--force-cdrom-device $cddevice --stderr-progress --output-wav $track -',
    };

    foreach my $p (@progs) {
        my $px = Thundaural::Server::Settings::program($p);
        if ($px) {
            chomp $px;
            my $px = sprintf('%s %s', $px, $progopts->{$p});
            return $px;
        }
    }
    &dumpstatus("idle", "unable to find an audio ripper (".join(', ', @progs).") (was --prog specified?)");
    exit;
}

sub find_audio_encoder {
    my $free = &free_disk_space(); # returns value in megabytes
    if (defined($free) && $free > 705) {
        # there is enough space to rip to wav and do background encoding
        return &find_audio_encoder_wav(@_);
    }
    return &find_audio_encoder_ogg(@_);
}

sub free_disk_space {
    my $sd = $sx->{storagedir};
    my $free;
    if (open(X, "/bin/df $sd |")) {
        my $line = <X>; # remove header line
        $line = <X>; # data line
        close(X);
        (undef, undef, undef, $free) = split(/\s+/, $line);
        $free /= 1024; # assume it's 1k blocks, divide by 1024 to get megs
    }
    return $free;
}

sub find_audio_encoder_wav {
    my $cdinfo = shift;
    my $track = shift;
    my $tracknum = shift;

    my $outfile = Thundaural::Util::mymktempname(
            $sx->{storagedir}, 
            $sx->{cddevice}, 
            sprintf('disc%s.track%02d.wav', $cdinfo->{cddbid}, $tracknum)
        );

    my $artist = $track->{performer};
    my $title = $track->{trackname};
    my $album = $cdinfo->{album}->{albumname};
    my $finalfile = sprintf("%s :: %s :: %02d :: %s.wav", &unslash($artist), &unslash($album), $tracknum, &unslash($title));
    
    return ("$0 --passthru '$outfile'", $outfile, $finalfile, '^\s*(\d+\.\d+)%', "\n");
}

sub find_audio_encoder_ogg {
    my $cdinfo = shift;
    my $track = shift;
    my $tracknum = shift;

    my @opts = (
        '--tracknum "$track"',
        '--artist "$artist"',
        '--title "$title"',
        '--album "$album"',
        '-c "RIPPER=$taversion"',
        '-c "ALBUMCDINDEXID=$cdindexid"',
        '-c "ALBUMCDDBID=$cddbid"',
        '-c "METASOURCE=$metasource"',
        '--output="$outfile"',
        '-'
    );
    my $opts = join(' ', @opts);
    my $px = Thundaural::Server::Settings::program('oggenc');
    if ($px && -x $px) {
        my $px = sprintf('%s %s', $px, $opts);

        my $outfile = Thundaural::Util::mymktempname(
                $sx->{storagedir}, 
                $sx->{cddevice}, 
                sprintf('disc%s.track%02d.ogg', $cdinfo->{cddbid}, $tracknum)
            );

        $px =~ s/\$outfile/$outfile/g;
        $px =~ s/\$track/$tracknum/g;

        my $artist = $track->{performer};
        my $title = $track->{trackname};
        my $idtype = $cdinfo->{idtype};
        my $cddbid = $cdinfo->{cddbid};
        my $cdindexid = $cdinfo->{cdindexid};
        my $album = $cdinfo->{album}->{albumname};
        my $tracklen = $track->{sectors} / 75; # in seconds
        my $metasource = $cdinfo->{source};
        if (int($tracklen) != $tracklen) {
            $tracklen = int($tracklen);
            $tracklen++; # final second is not a whole second, just add one
        }
        $px =~ s/\$artist\b/$artist/g;
        $px =~ s/\$title\b/$title/g;
        $px =~ s/\$album\b/$album/g;
        $px =~ s/\$taversion\b/$taversion/g;
        $px =~ s/\$cdindexid\b/$cdindexid/g;
        $px =~ s/\$cddbid\b/$cddbid/g;
        $px =~ s/\$metasource\b/$metasource/g;

        my $finalfile = sprintf("%s :: %s :: %02d :: %s.ogg", &unslash($artist), &unslash($album), $tracknum, &unslash($title));

        # [  3.8%] [ 0m45s remaining]
        #if (my($pct, $rem) = $line =~ m/\[\s*(\d+\.\d+)%\]\s+\[\s*(\d+m\d+s)\s+remaining\]/) {
        return ($px, $outfile, $finalfile, '\[\s*(\d+\.\d+)%\]\s+\[\s*(\d+m\d+s)\s+remaining\]', "\cM");
    }
    &dumpstatus('idle', 'unable to find audio encoder (oggenc) (was --prog specified?)');
    exit;
}

sub abortus {
    kill 15, -($$); # kill the process group
    exit;
};

sub pid_using_device($) {
    my $d = shift;

    my $p = Thundaural::Server::Settings::program('fuser');
    return undef unless ($p);
    my @x = `$p $d`;
    if (@x) {
        my $x = shift @x;
        my(undef, $p) = split(/\s+/, $x);
        return ($p+0) if ($p =~ m/^\d+f?$/);
    }
    return undef;
}

sub get_sort_dir {
    my $a = shift;

    $a =~ s/^\s+//;
    $a =~ s/^(An?\W+|The\W+|\W+)//i;
    ($a) = $a =~ m/^(\w)/;
    $a = lc $a;
    $a = 'x' if (!$a);
    return $a;
}

sub cleanup {
    &dumpstatus('busy', 'cleanup');
    my $pattern = Thundaural::Util::tmpnameprefix($sx->{storagedir}, $sx->{cddevice}).'*';
    my @files = bsd_glob($pattern);
    foreach my $f (@files) {
        unlink($f) if (-f $f);
    }
    sleep 2;
}

sub dumpstatus {
    my($state, $volume, $trackref, $performer, $name, $popularity, $rank, $length, $trackid, $started, $current, $percentage) = @_;
    push(@_, '', '', '', '', '', '', '', '', '', '', '', '', '');
    my @x = @_[0..11];
    my $dev = $sx->{cddevice} ? $sx->{cddevice} : '/dev/cdrom'; # use a rational default
    print $dev."\t".join("\t", @x)."\n";
    #print "$cddevice\t$state\t$volume\t$tracknum\t$artist\t$trackname\t$pct\t$corrections\n";
}

sub mydie {
    my $msg = shift;
    chomp $msg;
    $msg =~ tr/\t\n/ /;
    &dumpstatus('idle', sprintf('ripping failed with error "%s"', $msg));
    exit 1;
}

# dagrab can calculate this for us, but we're using oggenc's output 
# to keep track of progress, since that's a constant (and we might not have
# dagrab, but rather using cdda2wav or cdparanoia)
sub calc_speed($$) {
    my($length, $started, $pct) = @_;
    $pct /= 100;
    my $now = time();
    my $x1 = $now - $started;
    my $xc = $length * $pct;
    my $speed;
    eval { $speed = $xc / $x1; };
    $speed = 0 if ($@);
    $speed = sprintf("%.5f", $speed);
    return $speed;
}

sub passthru {
    my $outfile = shift;
    my $blocksize = shift;

    my $input = '';
    if (!defined($blocksize) || $blocksize+0 < 16384) {
        $blocksize = 16384;
    }
    if (read(STDIN, $input, 12) != 12) {
        die("unable to read wav header: $!\n");
    }
    my($riff, $length, $wav) = unpack('NVN', $input);
    if ($riff != 0x52494646 || $wav != 0x57415645) {
        die("input does not appear to be in wav format\n");
    }
    open(OUTPUT, ">$outfile") or die("unable to write to $outfile: $!\n");
    print OUTPUT $input;
    my $totalbytes = 0;
    while(my $bytesread = read(STDIN, $input, $blocksize)) {
        print OUTPUT $input;
        $totalbytes += $bytesread;
        my $pct = ($totalbytes / $length) * 100;;
        print STDERR sprintf('%.4f%% complete', $pct)."\n";
    }
    exit;
}

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
