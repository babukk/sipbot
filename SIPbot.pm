package SIPbot;

use strict;
use warnings;

use Net::SIP;
use DBI;
use threads;
use BotConfig;

# ----------------------------------------------------------------------------------------------------------------------

sub new {
    my ($class, $params) = @_;

    my $self;

    while (my ($k, $v) = each %{$params}) {
        $self->{ $k } = $v;
    }

    $self->{ 'config' } = new BotConfig({ 'CONFIG_FILE' => $self->{ 'conf_file' }, });
    $self->{ 'db_repeat_period' } = 5;

    if ($self->{ 'log_conf_file' }) {
        use Log::Log4perl;
        use Data::Dumper;

        $self->{ 'logger' } = Log::Log4perl->get_logger();
        Log::Log4perl::init($self->{ 'log_conf_file' });
    }

    eval {
        $self->{ 'dbh' } = DBI->connect(
            'DBI:mysql:' . $self->{ 'config' }->{ 'MYSQLDB' } . ';host='
                         . $self->{ 'config' }->{ 'MYSQLHOST' } . ';port=' . $self->{ 'config' }->{ 'MYSQLPORT' },
            $self->{ 'config' }->{ 'MYSQLUSER' }, $self->{ 'config' }->{ 'MYSQLPASS' },
            { RaiseError => 1, PrintError => 1, AutoCommit => 1, }
        );
    };
    if ($@) {
        $self->{ 'logger' }->info("SIPbot.pm: " . $@)   if $self->{ 'logger' };
        return undef;
    }

    $self->{ 'ua' } = Net::SIP::Simple->new(
        outgoing_proxy => $self->{ 'config' }->{ 'SIP_PROXY' } . ':' . $self->{ 'config' }->{ 'SIP_PROXY_PORT' },
        registrar => $self->{ 'config' }->{ 'SIP_SERVER' } . ':' . $self->{ 'config' }->{ 'SIP_SERVER_PORT' },
        from => $self->{ 'config' }->{ 'SIP_USER' },
        domain => $self->{ 'config' }->{ 'SIP_DOMAIN' },
        auth => [ $self->{ 'config' }->{ 'SIP_USER' }, $self->{ 'config' }->{ 'SIP_PASSWORD' } ],
        busy_by_invite => $self->{ 'config' }->{ 'BUSY_BY_INVITE' },
    );

    $self->{ 'ua' }->register;
    if ($self->{ 'ua' }->{ 'last_error' }) {
         $self->{ 'logger' }->error("SIPbot.pm: SIP error = " . $self->{ 'ua' }->{ 'last_error' })  if $self->{ 'logger' };
    }

    print Dumper($self->{ 'ua' });

    bless $self, $class;
    $self->{ 'db_thread' } = threads->create(sub{ $self->threadProc; });
    $self->{ 'db_thread' }->detach;

    return $self;
}

# ----------------------------------------------------------------------------------------------------------------------

sub DESTROY {
    my ($self) = @_;

    $self->{ 'logger' }->info("SIPbot.pm: DESTROY called.")  if $self->{ 'logger' };

    eval  { $self->{ 'dbh' }->disconnect; };
}

# ----------------------------------------------------------------------------------------------------------------------

sub run {
    my ($self) = @_;

    my $call;
    $self->{ 'ua' }->listen(
        cb_invite => sub {
            my ($status, $inv) = @_;

            my $From = $inv->get_header('From');
            $self->{ 'logger' }->info("new invite => " . $From)  if $self->{ 'logger' };
            $self->saveCallerID($From);

            return 1;
        },
    );
    $self->{ 'ua' }->loop(\$call);
}

# ----------------------------------------------------------------------------------------------------------------------

sub saveCallerID {
    my ($self, $from) = @_;

    my ($caller_id) = $from =~ m/\<(.*?)\>/;
    my $sth;

    eval {
=cut
        $sth = $self->{ 'dbh' }->prepare(" INSERT INTO  Calls
                                              SET  caller_id = ?,
                                                   call_time = now(),
                                                   expire_time = DATE_ADD( now(), INTERVAL ? second )
                                                                         ON DUPLICATE KEY UPDATE  caller_id = ? ");
=cut
        $sth = $self->{ 'dbh' }->prepare(" REPLACE INTO  Calls
                                              SET  caller_id = ?,
                                                   call_time = now(),
                                                   expire_time = DATE_ADD( now(), INTERVAL ? second )   ");
#=cut

    # $sth->execute($caller_id, $self->{ 'config' }->{ 'CALL_EXPIRE_TIME' }, $caller_id);
    $sth->execute($caller_id, $self->{ 'config' }->{ 'CALL_EXPIRE_TIME' });
    $sth->finish;
    undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error("SIPbot.pm: SQL error = " . $@)  if $self->{ 'logger' };
    }

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub removeExpiredCalls {
    my ($self, $dbh) = @_;

    my $sth;
    return;

    eval {
        $sth = $dbh->prepare(" SELECT  id, caller_id, call_time, expire_time  FROM  Calls  WHERE  expire_time < now() ");
        $sth->execute;
        while (my (@row) = $sth->fetchrow_array) {
            $self->{ 'logger' }->info("call expired => " . join('; ', @row))  if $self->{ 'logger' };
            my $sth = $dbh->prepare(" DELETE FROM  Calls  WHERE  id = ? ");
            $sth->execute($row[0]);
            $sth->finish;
            undef $sth;
        }
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $self->{ 'logger' }->error("SIPbot.pm: SQL error = " . $@)  if $self->{ 'logger' };
    }

    return;
}

# ----------------------------------------------------------------------------------------------------------------------

sub cloneDBh {
    my ($self) = @_;

    my $dbh;
    eval {
        $dbh = DBI->connect(
            'DBI:mysql:' . $self->{ 'config' }->{ 'MYSQLDB' } . ';host='
                         . $self->{ 'config' }->{ 'MYSQLHOST' } . ';port=' . $self->{ 'config' }->{ 'MYSQLPORT' },
            $self->{ 'config' }->{ 'MYSQLUSER' }, $self->{ 'config' }->{ 'MYSQLPASS' },
            { RaiseError => 1, PrintError => 1, AutoCommit => 1, }
        );
    };
    if ($@) {
        $self->{ 'logger' }->info("SIPbot.pm: " . $@)   if $self->{ 'logger' };
        return undef;
    }

    return $dbh;
}

# ----------------------------------------------------------------------------------------------------------------------

sub threadProc {
    my ($self) = @_;

    my $newdbh = $self->cloneDBh();
    while (1) {
        $self->removeExpiredCalls($newdbh);
        sleep $self->{ 'config' }->{ 'DB_REPEAT_PERIOD' };
    }
    $newdbh->disconnect;

    return;
}

1;
