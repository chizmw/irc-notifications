# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;
use lib 'lib';

name 'IRC-Notifications';
all_from 'irc_appnotify.pl';

# find what we use with:
#    egrep -rh '^use ' lib/ |sort |uniq
requires(
    #'Irssi'                 => 0,
    'Net::AppNotifications' => 0,
);

WriteAll;
