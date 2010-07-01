package presque::StatusHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
  'presque::Role::Queue::Names',
  'presque::Role::Error',
  'presque::Role::Response';

__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $queue_name) = @_;

    if ($queue_name) {
        my $key = $self->_queue($queue_name);
        $self->application->redis->llen(
            $key,
            sub {
                my $size = shift;
                $self->entity({queue => $queue_name, size => $size});
            }
        );
    }
    else {
        $self->application->redis->smembers(
            $self->_queue_set,
            sub {
                my $res = shift;
                $self->entity({queues => $res, size => scalar @$res});
            }
        );
    }
}

1;
__END__

=head1 NAME

presque::StatusHandler - return the current size of a queue

=head1 DESCRIPTION

Return the current size of a queue

=head2 GET

=over 4

=item path

/status/:queue_name

=item request

=item response

content-type : application/json

code : 200

content : {"queue":"queue_name", "size":10}

=back

The response contains the following informations

=over 2

=item B<queue>

name of the queue

=item B<size>

size of the queue

=back

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
