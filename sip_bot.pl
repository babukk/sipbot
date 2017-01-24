#! /usr/bin/perl -w
#--------------------------------------------------------------------------------------------------------------

use strict;
use warnings;
use lib qw( . );

use SIPbot;
use Data::Dumper;

my $sip_bot = SIPbot->new({
    'conf_file'          => './sip_bot.conf',
    'log_conf_file'      => './logger.conf',
});

# print Dumper($sip_bot);
# &daemonize($sip_bot);

$sip_bot->run;


# --------------------------------------------------------------------------------------------

sub daemonize {
    my ($bot) = @_;

    use POSIX;
    POSIX::setsid or die "setsid: $!";
    my $pid = fork ();

    if ($pid < 0) {
        die "fork: $!";
    }
    elsif ($pid) {
        exit 0;
    }

    chdir "/";
    umask 0;
    foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024)) {
        POSIX::close $_;
    }

    open(STDIN, "</dev/null");
    open(STDOUT, ">/dev/null");
    open(STDERR, ">&STDOUT");

    $bot->run;

    return;
}
