#!/bin/bash

# $Header: /home/cvs/thundaural/client/xinitrc.sh,v 1.1 2004/03/21 04:53:03 jukebox Exp $

#if [ "x$1" = 'x' ]; then
#	echo "please specify the run-time directory as the first argument"
#	exit 1
#fi
#
#if [ ! -d $1 ]; then
#	echo "$1 is not a directory"
#	exit 2
#fi

xscreensaver -nosplash &
xsetroot -solid grey40
xload -geometry 700x75-0-0 -update 3 &

cd `dirname $0`
/usr/bin/perl ./interface.pl > /dev/null 2>&1
