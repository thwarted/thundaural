#!/usr/bin/perl

use strict;
use warnings;

use lib '.';

use Carp qw(cluck);
use Data::Dumper;
use Storable qw(freeze thaw);

use SDL;
use SDL::Surface;
use SDL::App;
use SDL::Event;
use SDL::Color;
use SDL::Font;
use SDL::TTFont;
use SDL::Tool::Graphic;
use SDL::Cursor;

require 'SDL_Perl_Ext.pl';

use Thundaural::Logger qw(logger);
use Thundaural::Client::Interface;

use Themes::Original;

our $tmpdir = "/tmp/newclient-cache-$$";
our $starttime = time();
mkdir $tmpdir, 0700;

END { my $x = $?; if ($tmpdir && -d $tmpdir) { `/bin/rm -rf $tmpdir`; } $? = $x; }

$SIG{__WARN__} = sub { cluck($@); };

Thundaural::Logger::init('stderr');
our $client = new Thundaural::Client::Interface(host=>'jukebox', port=>9000);

my $al = $client->albums(offset=>0, count=>3);
foreach my $a (@$al) {
    print "Album : ".$a->albumid()."\n";
    print "Name  : ".$a->name()."\n";
    print "Perf  : ".$a->performer()."\n";
    print "Tracks: ".$a->tracks()."\n";
    print(("-"x50)."\n");
}

&mainloop;

our $theme;

sub mainloop {

    my $app = new SDL::App(-title=>q{Thundaural Jukebox}, -width=>1024, -height=>768, -depth=>24, -full=>0,
                -flags=>SDL::SDL_DOUBLEBUF | SDL::SDL_HWSURFACE | SDL::SDL_HWACCEL);
    die("creation of SDL::App failed") if (!$app);

    #my $x = new SDL::Surface(-name=>'./images/1024x768-Appropriately-Left-Handed-1.png');
    #$x->display_format();
    #$x->blit(0, $app, 0);

    $theme = new Themes::Original;
    $theme->start();
    $theme->draw_background(canvas=>$app, source=>new SDL::Rect(-width=>$app->width(), -height=>$app->height() ));

    #my $x = new SDL::Surface(-name=>'images/goto-albums.png');
    #$x->display_format();
    #$x = SDL::Tool::Graphic::zoom(undef, $x, 2.2, 2.2, 1);
    #$x->blit(0, $app, 0);
    #$app->sync();
    #sleep 5;

    #$app->fill(0, new SDL::Color(-r=>160, -g=>160, -b=>160));
    $app->sync();
    my $e = new SDL::Event;
    while(1) {
        my $updates = 0;
        my $ticks = $app->ticks();
        while(my($n, $s, $r, $sync) = $theme->get_blit( ticks=>$ticks )) {
            if ($s && $r) {
                my $rn = new SDL::Rect($r->tohash()); # -x=>$r->x, -y=>$r->y, -width=>$r->width, -height=>$r->height);
                if ($s eq 'background') {
                    $theme->draw_background(canvas=>$app, source=>$rn);
                    #logger("drawing $n ($s) @ %s", $rn->tostr());
                } else {
                    $s->blit(0, $app, $rn);
                    #logger("drawing $n ($s)");
                }
                if ($sync) {
                    $app->update($rn);
                } else {
                    $updates++;
                }
            }
        }
        if ($updates) {
            #logger("blitted $updates surfaces");
            $app->sync();
            my $tickdiff = $app->ticks() - $ticks;
            #logger("ticks to do draw cycle: $tickdiff");
        }
        if ($e->poll()) {
            my $type = $e->type();
            if ($type != SDL::SDL_MOUSEMOTION) {
                if ($type == SDL::SDL_KEYUP) {
                    my $key = $e->key_name();
                    last if ($key eq 'q');
                    $app->fullscreen if ($key eq 'f');
                    if ($key eq 'r') {
                        $client->clear_cache();
                    }
                }
                my $ticks = $app->ticks();
                #logger("event @ $ticks");
                $theme->receive_event(ticks=>$ticks, event=>$e);
            }
        }
        if (!$updates) {
            $app->delay(10);
        }
    }
    $theme->stop();
}

