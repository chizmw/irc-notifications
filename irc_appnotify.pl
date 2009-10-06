use Irssi qw(active_server);
use Net::AppNotifications;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '0.01';
%IRSSI = (
    authors     => 'Chisel Wright',
    name        => 'irc_appnotify',
    description => 'Alerts for IRC events via Notifications app',
    license     => 'Artistic'
);

Irssi::settings_add_str ('irc_appnotify', 'notify_regexp',          '.+');
Irssi::settings_add_str ('irc_appnotify', 'notify_key',             'KEY_GOES_HERE');
Irssi::settings_add_bool('irc_appnotify', 'notify_direct_only',     1);
Irssi::settings_add_bool('irc_appnotify', 'notify_debug',           0);
Irssi::settings_add_str ('irc_appnotify', 'notify_method',          'iPhone');

my $spew = Irssi::settings_get_str('notify_debug');

# TODO factor out into other voodoo
sub notify_iPhone {
    my $msg  = shift;

    Irssi::print('notify_iPhone') if $spew;

    my $look_for = Irssi::settings_get_str('notify_regexp');
    my $key      = Irssi::settings_get_str('notify_key');

    my $look_for_re = qr{$look_for};

    if (not $msg =~ m{$look_for_re}) {
        Irssi::print "didn't match RE: $look_for_re"
            if $spew;
        return;
    }

    my $notifier = Net::AppNotifications->new(key => $key);

    $notifier->send(
        message    => "$msg",
        on_success => sub { Irssi::print "Notification delivered: $msg" },
        on_error   => sub { Irssi::print "Notification NOT delivered: $msg" },
    );

    return;
}

# either use "notify_method" or Irssi::print
sub send_notification {
    my $msg  = shift;

    my $notify_func =
          q{notify_}
        . Irssi::settings_get_str('notify_method')
    ;

    if (__PACKAGE__->can($notify_func)) {
        no strict 'refs';
        &${notify_func}($msg);
    }
    else {
        Irssi::print($msg);
    }
}

# deal with public messages
sub public {
    my ($server,$msg,$nick,$address,$target)=@_;
    Irssi::print(qq[$msg,$nick,$address,$target])
        if $spew;

    my $own_nick = active_server->{nick};

    # addressed directly
    if ($msg =~ s{\A${own_nick}:\s}{}) {
        # we've stripped the reference to us out
        $msg = qq{$target: Direct from $nick: $msg};
    }
    else {
        # are we only wanting direct communications?
        my $direct_only = Irssi::settings_get_bool('notify_direct_only');
        Irssi::print $direct_only
            if $spew;
        if (defined $direct_only and $direct_only) {
            Irssi::print "skipping non-direct message: $msg"
                if $spew;
            return;
        }

        # set the message
        $msg = qq{$target: $nick: $msg};
    }
    send_notification($msg);
}
 
# deal with private messages
sub private {
    my ($server,$msg,$nick,$address)=@_;
    #public($server,$msg,$nick,$address,$nick);
    $msg = qq{Private from $nick: $msg};
    send_notification($msg);
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
Irssi::print "$IRSSI{name} $VERSION ready";
