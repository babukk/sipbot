package BotConfig;

use strict;
use warnings;

# ----------------------------------------------------------------------------------------------------------------------

sub new {
    my ($class, $params) = @_;

    my $self;

    while (my ($k, $v) = each %{$params}) {
        $self->{ $k } = $v;
    }

    $self->{ 'CONFIG_FILE' } = './sip_bot.conf'                unless $self->{ 'CONFIG_FILE' };

    eval {
        open(CONF_FILE, "<" . $self->{ 'CONFIG_FILE' });
        while (<CONF_FILE>) {
            $self->{ $1 } = $2  if ($_ =~ /^(\S+)+\s*=\s*(\S+)$/);
        }
        close CONF_FILE;
    };

    $self->{ 'MYSQLHOST' } = 'localhost'                        unless $self->{ 'MYSQLHOST' };
    $self->{ 'MYSQLPORT' } = '3306'                             unless $self->{ 'MYSQLPORT' };
    $self->{ 'MYSQLDB' } = 'sip_bot'                            unless $self->{ 'MYSQLDB' };
    $self->{ 'MYSQLUSER' } = 'sip_bot'                          unless $self->{ 'MYSQLUSER' };
    $self->{ 'MYSQLPASS' } = '123456'                           unless $self->{ 'MYSQLPASS' };
    $self->{ 'DB_REPEAT_PERIOD' } = 60                          unless $self->{ 'DB_REPEAT_PERIOD' };
    $self->{ 'CALL_EXPIRE_TIME' } = 180                         unless $self->{ 'CALL_EXPIRE_TIME' };
    $self->{ 'BUSY_BY_INVITE' } = 1                             unless $self->{ 'BUSY_BY_INVITE' };

    bless $self, $class;

    return $self;
}

1;
