#!perl

# HACK
use lib q{/Users/c.wright/development/perl-net-appnotifications/lib};

use Irssi qw(active_server);
# For 0.0.2 you'll currently need to fetch from:
# http://github.com/chiselwright/perl-net-appnotifications/
use Net::AppNotifications 0.02;
use Regexp::Common qw /URI/;
use AnyEvent::HTTP;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.07';
%IRSSI = (
    authors     => 'Chisel Wright',
    name        => 'irc_appnotify',
    description => 'Alerts for IRC events via Notifications app',
    license     => 'Artistic'
);


Irssi::settings_add_str ('irc_appnotify', 'notify_regexp',          '.+');
Irssi::settings_add_str ('irc_appnotify', 'notify_key',             'KEY_GOES_HERE');
Irssi::settings_add_bool('irc_appnotify', 'notify_direct_only',     1);
Irssi::settings_add_bool('irc_appnotify', 'notify_inactive_only',   1);
Irssi::settings_add_bool('irc_appnotify', 'notify_iphone_silent',   0);
Irssi::settings_add_int ('irc_appnotify', 'notify_debug',           0);
Irssi::settings_add_str ('irc_appnotify', 'notify_method',          'iPhone');
Irssi::settings_add_str ('irc_appnotify', 'notify_methods',         'iPhone,Growl');
Irssi::settings_add_str ('irc_appnotify', 'notify_growl',           'growlnotify');
Irssi::settings_add_str ('irc_appnotify', 'notify_proxy',           undef);

sub spew {
    my $level = shift || 1;
    return (Irssi::settings_get_int('notify_debug') >= $level);
}

sub message_data {
    my $msg  = shift;
	my $src  = shift;
    my $tgt  = shift;

    my %data;

	$data{title}        = (defined $src) ? "$src" : "IRC Alert";

	$data{long_message} = $msg;
	$data{long_message} =~ s{($RE{URI}{HTTP})}{<a href="$1">$1</a>}g;

    $data{preview}      = $msg;
	$data{preview}      =~ s{($RE{URI}{HTTP})}{[url]}g;
    $data{preview}      = substr($data{preview},0,30);

    $data{subtitle}     = $tgt;
    $data{target}       = $tgt;

    return \%data;
}

# TODO factor out into other voodoo
sub notify_iPhone {
    my $msg  = shift;
	my $src  = shift;
    my $tgt  = shift;

    Irssi::print('notify_iPhone') if spew(3);

    # set the proxy (or unset, if we're undefined)
    AnyEvent::HTTP::set_proxy(Irssi::settings_get_str('notify_proxy'));

    my $look_for = Irssi::settings_get_str('notify_regexp');
    my $key      = Irssi::settings_get_str('notify_key');

    my $look_for_re = qr{$look_for};

    if (not $msg =~ m{$look_for_re}) {
        Irssi::print "didn't match RE: $look_for_re"
            if spew(3);
        return;
    }

    # fetch tidied up data for the notification
    my $data = message_data($msg, $src, $tgt);

    my $notifier = Net::AppNotifications->new(key => $key);

    # http://developer.appnotifications.com/p/user_notifications.html
    $notifier->send(
        title                   => $data->{title},
        message                 => $data->{preview},
        long_message            => $data->{long_message},
		silent                  => Irssi::settings_get_bool('notify_iphone_silent'),
		sound		            => 4,
        icon_url                => 'http://www.clker.com/cliparts/5/b/9/8/1194984513646717809chat_icon_01.svg.med.png',
        long_message_preview    => $data->{preview},
        subtitle                => $data->{subtitle},

        on_success              => sub { Irssi::print "Notification delivered: $msg" if spew},
        on_error                => sub { Irssi::print "Notification NOT delivered: $msg" },
    );

    return;
}
 sub notify_Growl {
    my $msg  = shift;
	my $src  = shift;
    my $tgt  = shift;
    my $app  = Irssi::settings_get_str('notify_growl') || 'growlnotify';

    # fetch tidied up data for the notification
    my $data = message_data($msg, $src, $tgt);

    # the arguments for growl
    my @args = (
        $app,
        '--name',           'irssi',
        '--message',        $data->{preview},
        '--title',          "$data->{title} : $data->{subtitle}",
        '--icon',           'txt',
    );

    system @args;
    return;
 }

sub active_window_name {
    # what's our active window?
    my $active =
           Irssi::active_win()->{active}{address}
        || Irssi::active_win()->{name}
        || Irssi::active_win()->{active}{name}
    ;
    return $active;
}

# either use "notify_method" or Irssi::print
sub send_notification {
    my $msg  = shift;
	my $src  = shift;
    my $tgt  = shift;

    # what's our active window?
    my $active = active_window_name();

    # are we looking where the message is destined to be?
    if ($active eq $tgt) {
        Irssi::print( "message and focus are both: <$active> <$tgt>" )
            if spew(3);
        # message is where we're looking
        my $inactive_only = Irssi::settings_get_bool('notify_inactive_only');
        # don't send anything if we only want to know about the channel we
        # *are not* looking at
        if ($inactive_only) {
            Irssi::print( "skipping $msg" )
                if spew(4);
            return;
        }
    }
    # set notify_debug >= 4 if you want some extra information
    else {
        if (spew(4)) {
            Irssi::print( "* active window: $active" );
            Irssi::print( "* target: $tgt" );
        }
    }

    # how would the user like to be informed?
    # we now handle a list of methods
    my @notify_funcs;
    if (my $notify_list = Irssi::settings_get_str('notify_methods')) {
        @notify_funcs = split(m{\s*,\s*}, $notify_list);
    }
    else {
        @notify_funcs = (
            Irssi::settings_get_str('notify_method')
        );
    }
    @notify_funcs = map { q{notify_} . $_ } @notify_funcs;

    my $notify_count = 0;

    foreach my $notify_func (@notify_funcs) {
        Irssi::print( "trying to call: $notify_func" )
            if spew(3);
        # do we have a function to support the desired method?
        if (__PACKAGE__->can($notify_func)) {
            $notify_count++;
            no strict 'refs';
            &${notify_func}($msg,$src,$tgt);
        }
    }
    if (not $notify_count) {
        Irssi::print($msg,$src);
    }
}

# deal with public messages
sub public {
    my ($server,$msg,$nick,$address,$target)=@_;
    Irssi::print(qq[$msg,$nick,$address,$target])
        if spew(3);

    my $own_nick = active_server->{nick};

    # addressed directly
    if ($msg =~ s{\A${own_nick}:\s}{}) {
        # we've stripped the reference to us out
        $msg = qq{$target: Direct from $nick: $msg};
    }
    else {
        # are we only wanting direct communications?
        my $direct_only = Irssi::settings_get_bool('notify_direct_only');
        Irssi::print "notify_direct_only = $direct_only"
            if spew(3);
        if (defined $direct_only and $direct_only) {
            Irssi::print "skipping non-direct message: $msg"
                if spew(2);
            return;
        }

        # set the message
        $msg = qq{$target: $nick: $msg};
    }
    send_notification($msg,$target,$target);
}
 
# deal with private messages
sub private {
    my ($server,$msg,$nick,$address)=@_;
    #public($server,$msg,$nick,$address,$nick);
    $msg = qq{Private from $nick: $msg};
    send_notification($msg, $nick,$address);
}
 
# our own public messages ... get treated like public messages
sub own_public {
    my ($server,$msg,$target)=@_;
    public($server,$msg,$server->{nick},0,$target);
}
 
# our own private messages ... get treated like private messages
sub own_private {
    my ($server,$msg,$target,$otarget)=@_;
    private($server,$msg,$server->{nick},0,$target);
}
 
# signals we want to act on
Irssi::signal_add_last('message public',      'public');
Irssi::signal_add_last('message private',     'private');
Irssi::signal_add_last('message own_public',  'own_public');
Irssi::signal_add_last('message own_Private', 'own_private');

# let the work know we're up and running
Irssi::print "$IRSSI{name} $VERSION ready" if spew(1);
Irssi::print "$IRSSI{name} : using Net::AppNotifications version $Net::AppNotifications::VERSION"   if spew(1);
