#!/bin/sh

if [ ! -d $HOME/.irssi/scripts ]; then
    mkdir -vp $HOME/.irssi/scripts;
fi

if [ ! -d $HOME/.irssi/scripts/autorun ]; then
    mkdir -vp $HOME/.irssi/scripts/autorun;
fi

ln -s $PWD/irc_appnotify.pl $HOME/.irssi/scripts;
ln -s $PWD/irc_appnotify.pl $HOME/.irssi/scripts/autorun;
