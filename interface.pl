#!/usr/bin/perl

use strict;
use warnings;

use lib '.';

use Carp qw(cluck confess);
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
my $app;
our $client;
our $theme;

mkdir '/tmp/newclient', 0777;
our $tmpdir = "/tmp/newclient/cache-$$";
our $starttime = time();
mkdir $tmpdir, 0700;

END { my $x = $?; if ($tmpdir && -d $tmpdir) { `/bin/rm -rf $tmpdir`; } $? = $x; }

$SIG{__WARN__} = sub { cluck(@_) };
$SIG{__DIE__} = sub { confess(@_) };

Thundaural::Logger::init('stderr');

&mainloop;

sub mainloop {

    $app = new SDL::App(-title=>q{Thundaural Jukebox}, -width=>1024, -height=>768, -depth=>24, -full=>0,
                -flags=>SDL::SDL_DOUBLEBUF | SDL::SDL_HWSURFACE | SDL::SDL_HWACCEL);
    die("creation of SDL::App failed") if (!$app);

    $client = new Thundaural::Client::Interface(host=>'localhost', port=>9000, errorfunc=>\&error_message);

    $theme = new Themes::Original;
    $theme->start();
    $theme->draw_background(canvas=>$app, source=>new SDL::Rect(-width=>$app->width(), -height=>$app->height() ));

    my $al = $client->albums(offset=>0, count=>3);
    foreach my $a (@$al) {
        print "Album : ".$a->albumid()."\n";
        print "Name  : ".$a->name()."\n";
        print "Perf  : ".$a->performer()."\n";
        print "Tracks: ".$a->tracks()."\n";
        print(("-"x50)."\n");
    }

    #my $x = new SDL::Surface(-name=>'./images/1024x768-Appropriately-Left-Handed-1.png');
    #$x->display_format();
    #$x->blit(0, $app, 0);

    #my $x = new SDL::Surface(-name=>'images/goto-albums.png');
    #$x->display_format();
    #$x = SDL::Tool::Graphic::zoom(undef, $x, 2.2, 2.2, 1);
    #$x->blit(0, $app, 0);
    #$app->sync();
    #sleep 5;

    #$app->fill(0, new SDL::Color(-r=>160, -g=>160, -b=>160));
    $app->sync();
    my $e = new SDL::Event;
    my $nextheartbeat = 0;
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
        if ($ticks > $nextheartbeat) {
            $nextheartbeat = $ticks += $theme->heartbeat();
        }
        if (!$updates) {
            $app->delay(10);
        }
    }
    $theme->stop();
}

sub error_message {
    my $state = shift;

    if ($state eq 'show') {
        return &error_show_message(@_);
    } elsif ($state eq 'idle') {
        return &error_idle();
    } elsif ($state eq 'recovered') {
        if (ref($theme)) {
            my $area = new SDL::Rect(-width=>$app->width(), -height=>$app->height(), -x=>0, -y=>0);
            $theme->redraw($area);
        }
        return;
    }
    logger("unknown error message state \"$state\"");
}

sub error_show_message {
    my $bgcolor = new SDL::Color(-r=>160, -g=>160, -b=>160);
    my $fgcolor = new SDL::Color(-r=>0, -g=>0, -b=>0);
    $app->fill(0, $bgcolor);
    my $font = new SDL::TTFont(-name=>"./fonts/Vera.ttf", -size=>17, -bg=>$bgcolor, -fg=>$fgcolor);

    my @lines = qw(hellofd asfd jfas dfd);
    if (scalar @_ == 1) {
        @lines = split(/\n/, shift);
    } else {
        @lines = @_;
    }
    $font->print_lines_justified(just=>0, x=>$app->width() / 2, y=>200, maxwidth=>$app->width()-100, lines=>\@lines, surface=>$app);
    $app->sync();
}

sub error_idle {
    my $nowticks = SDL::App::ticks();
    while(SDL::App::ticks() - $nowticks < 3000) {
        my $event = new SDL::Event;
        while($event->poll()) {
            my $type = $event->type();
            if ($type == SDL::SDL_QUIT) { logger("request quit"); exit; }
            if ($type == SDL::SDL_KEYDOWN) { if ($event->key_name() eq 'q') { logger("exiting"); exit; } }
        }
        SDL::App::delay(0, 50);
    }
}

