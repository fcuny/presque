package presque;

our $VERSION = '0.01';

use AnyEvent::Redis;
use Moose;
extends 'Tatsumaki::Application';

has config => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        redis => {
            host => 'localhost',
            port => 6379,
        },
    }
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

sub h {
    my $class = shift;
    eval "require $class" or die $@;
    $class;
}

sub app {
    my ($class, %args) = @_;
    my $self = $class->new(
        [   '/qb/(.*)' => h('presque::RestQueueBatchHandler'),
            '/q/(.*)'  => h('presque::RestQueueHandler'),
            '/j/(.*)'       => h('presque::JobQueueHandler'),
            '/w/(.*)'       => h('presque::WorkerHandler'),
            '/status/(.*)'  => h('presque::StatusHandler'),
            '/control/(.*)' => h('presque::ControlHandler'),
            '/'             => h('presque::IndexHandler'),
        ]
    );

    $self->config(delete $args{config});
    $self;
}

1;
__END__

=head1 NAME

presque - a redis/tatsumaki based message queue

=head1 SYNOPSIS

=head1 DESCRIPTION

presque is a persistent job queue that uses Redis for storage and Tatsumaki for the interface between workers and Redis.

presque implement a REST interface for communications, and jobs are JSON data structure.

Workers can be written in any language as long as they implement the REST interface. A complete worker exists for Perl L<presque::worker>. Some examples in other languages can be found in the B<eg> directory.

The functionalities are inspired by L<RestMQ|http://github.com/gleicon/restmq> and L<resque|http://github.com/defunkt/resque>.

=head2 HTTP ROUTES

The following HTTP routes are available:

=over 4

=item B<GET /q/queuename>

gets an object out of the queue

=item B<POST /q/queuename>

insert an object in the queue

=item B<PUT /q/queuename>

re-insert a job after a worker failed to process the job

=item B<DELETE /q/queuename>

purge and delete the queue

=item B<GET /status/>

informations about a queue.

=item B<GET /j/queuename>

return some basic information about a queue.

=item B<GET /control/queuename>

return the status of the queue. A queue have two statues: open or closed. When a queue is closed, no job can be extracted from the queue.

=item B<POST /control/queuename>

change the status of the queue.

=item B<GET /w/>

some statisctics about a worker

=item B<POST /w/queuename>

register a worker on a queue.

=item B<DELETE /w/queue_name>

unregister a worker on a queue.

=back

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

For a complete description of each routes, refer to L<presque::WorkerHandler>, L<presque::RestQueueHandler>, L<presque::ControlHandler>, L<presque::JobQueueHandler>, L<presque::StatusHandler>.

For a complete worker see L<presque::worker>.

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
