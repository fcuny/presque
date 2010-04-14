package presque;

use Moose;
our $VERSION = '0.01';
extends 'Tatsumaki::Application';

use AnyEvent::Redis;

use presque::RestQueueHandler;
use presque::JobQueueHandler;
use presque::IndexHandler;
use presque::StatusHandler;
use presque::ControlHandler;

has config => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { }
);

has redis => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;
        AnyEvent::Redis->new(
            host => $self->config->{redis}->{host},
            port => $self->config->{redis}->{port}
        );
    }
);

sub app {
    my ( $class, %args ) = @_;
    my $self = $class->new(
        [
            '/q/(.*)'       => 'presque::RestQueueHandler',
            '/j/(.*)'       => 'presque::JobQueueHandler',
            '/stats/(.*)'   => 'presque::StatusHandler',
            '/control/(.*)' => 'presque::ControlHandler',
            '/'             => 'presque::IndexHandler',
        ]
    );
    $self->config( delete $args{config} );
    $self;
}

1;
__END__

=head1 NAME

presque - a redis based message queue

=head1 SYNOPSIS

=head1 DESCRIPTION

presque is a message queue system based on Tatsumaki and Redis.

It's functionality are inspired by L<RestMQ|http://github.com/gleicon/restmq>
and the name by L<resque|http://github.com/defunkt/resque>.

The following HTTP routes are available:

=over 4

=item B<GET /q/queuename>

gets an object out of the queue

=item B<POST /q/queuename>

insert an object in the queue

=item B<DELETE /q/queuename>

purge and delete the queue

=item B<GET /stats/[queuename]>

return some statues about the queue. If no queue is given, return basic statues about
all the queues.

=item B<GET /j/queuename>

return some basic information about a queue.

=item B<GET /control/queuename>

=item B<POST /control/queuename>

=back

=head2 INSERT A JOB

The B<Content-Type> of the request must be set to B<application/json>. The body of the request
must be a valid JSON object.

    curl -H 'Content-Type: application/json' -X POST "http://localhost:5002/q/foo" -d '{"key":"value"}'

=head2 FETCH A JOB

Return a JSON object

   curl http://localhost:5002/q/foo

=head2 PURGE AND DELETE A QUEUE

   curl -X DELETE http://localhost:5002/q/foo

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
