package presque::StatusHandler;

use Moose;
extends 'Tatsumaki::Handler';
with
  qw/presque::Role::QueueName presque::Role::Error presque::Role::Response/;

__PACKAGE__->asynchronous(1);

use JSON;

sub get {
    my ( $self, $queue_name ) = @_;

    my $conf = $self->application->config->{redis};
    my $stats = { redis => $conf->{host} . ':' . $conf->{port}, };

    if ($queue_name) {
        my $key = $self->_queue($queue_name);
        $self->application->redis->llen(
            $key,
            sub {
                my $size = shift;
                $stats->{queue} = $queue_name;
                $stats->{size}  = $size;
                my $json = JSON::encode_json($stats);
                $self->finish($json);
            }
        );
    }
    else {
        $self->application->redis->smembers(
            'QUEUESET',
            sub {
                my $res = shift;
                $stats->{queues} = $res;
                $stats->{size}   = scalar @$res;
                $self->finish( JSON::encode_json($stats) );
            }
        );
    }
}

1;
__END__

=head1 NAME

presque::IndexHandler - a redis based message queue

=head1 DESCRIPTION

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
