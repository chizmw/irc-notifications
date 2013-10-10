# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;
use lib 'lib';

name 'IRC-Notifications';
license 'perl';
version_from 'irc_appnotify.pl';
author 'Chisel <chisel at chizography.net>';


# find what we use with:
#    egrep -rh '^use ' lib/ |sort |uniq
requires(
    #'Irssi'                 => 0,
    #'Net::AppNotifications' => 0,
	'Regexp::Common'		=> 0,
);

install_script('irc_appnotify.pl');
auto_install;

WriteAll;
