#!/usr/bin/perl

package Themes::Original::AlbumCover;

use strict;
use warnings;

use Carp qw(cluck);
use Data::Dumper;
use Storable qw(freeze);

use SDL;
use SDL::Rect;
use SDL::Surface;

use Thundaural::Logger qw(logger);

use Widget::Button;
use base 'Widget::Button';

sub widget_initialize {
    my $this = shift;
    my %o = @_;

    $this->SUPER::widget_initialize(@_);

    my $area = $this->area();

    $this->{bgcolor} = new SDL::Color(-r=>110, -g=>110, -b=>110);
    $this->{fgcolor} = new SDL::Color(-r=>255, -g=>255, -b=>255);
    $this->{font} = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>20, -bg=>$this->{bgcolor}, -fg=>$this->{fgcolor});

    $this->{blank} = new SDL::Surface(-width=>$area->width(), -height=>$area->height(), -depth=>24);;
    $this->{blank}->display_format();

    $this->{album} = undef;
    $this->{lastalbum} = 0;

    $this->{lastdata} = '';
    $this->{lastsize} = -1;
}

sub set_album {
    my $this = shift;
    my %o = @_;
    my $clear = $o{clear};
    my $album = $o{album};
    my $rippedat = $o{rippedat};

    if ($clear) {
        logger("clearing coverart");
        $this->erase();
        $this->visible(0);
        $this->{lastdata} = '';
        $this->{lastsize} = -1;
        return;
    }

    if (ref($album) eq 'Thundaural::Client::Album') {
        $this->{album} = $album;
        my $coverart = $this->{album}->coverartfile();

        my $newsize = $coverart ? -s $coverart : -1;
        $newsize = -1 if (!$newsize);
        if ($newsize != $this->{lastsize}) {
            if ($coverart ne $this->{lastdata}) {
                $this->set_frame(frame=>0, file=>$coverart, resize=>1);
                $this->make_depressed_frame();
                $this->{lastdata} = $coverart;
                $this->{lastsize} = $newsize;
                $this->visible(1);
                $this->redraw();
            }
        } elsif ($newsize == -1) {

            my @lines;
            if ($album->state() eq 'ripping' && $album->type() eq 'read') {
                @lines = 'no cover art found';
            } else {
                my $pf = $album->performer() || ' ';
                my $n = $album->name() || ' ';
                @lines = ($pf, ' ', $n);
            }
            my $nowdata = join('', @lines);
            logger("now data = $nowdata");
            if ($this->{lastdata} ne $nowdata) {
                $this->{blank}->fill(0, $this->{bgcolor});
                my @text = $this->{font}->wrap(rect=>$this->{blank}, lines=>[@lines]);
                my $textheight = $this->{font}->height() * (scalar @text);
                my $surfheight = $this->{blank}->height();
                my $y = ($surfheight - $textheight) / 2;
                $this->{font}->print_lines_justified(just=>0, surf=>$this->{blank}, x=>int($this->{blank}->width() / 2), y=>$y, lines=>\@text);

                $this->set_frame(frame=>0, surface=>$this->{blank}, resize=>1);
                $this->make_depressed_frame();
                $this->{lastdata} = $nowdata;
                $this->{lastsize} = -1;
                $this->visible(1);
                $this->redraw();
            }
        }
    }

    if ($album eq 'ripping' && $rippedat) {
        my $outfile = sprintf('%s/thundaural-coverartcache-ripping-%d.jpg', $main::tmpdir, $rippedat);
        if (-e $outfile && $outfile eq $this->{lastdata} && -s $outfile == $this->{lastsize}) {
            # nothing to do
        } else {
            my $x = $main::client->coverart(albumid=>'ripping', outputfile=>$outfile);
            $this->set_frame(frame=>0, file=>$outfile, resize=>1);
            $this->make_depressed_frame();
            $this->{lastdata} = $outfile;
            $this->{lastsize} = -s $outfile;
            $this->{lastsize} = -1 if (!$this->{lastsize});
            $this->visible(1);
            $this->redraw();
        }
    }
}

1;

__END__

sub coverartfile($) {
    my $this = shift;
    my $albumid = $this->{albumid};

    my $tmpfile = $this->_coverart_localfile($albumid);
    if (! -s $tmpfile) {
        #if (defined($x) && ($tmpfile eq $x)) {
            #$this->{coverartfile} = $x;
            #return $x;
        #}
    }
    return $tmpfile;
}

sub _coverart_localfile {
    my $this = shift;

    if ($this->{albumid} eq 'ripping') {

    }

    my $f = ref($album) ? freeze($album->hash()) : '';
    if (ref($album)) {
        print Dumper($album->hash());
    }
    if ($f eq $this->{lastalbum}) {
        logger('no changes to album cover');
        return;
    }
    $this->{lastalbum} = $f;


}

1;

