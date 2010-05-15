package presque;

our $VERSION = '0.01';

use AnyEvent::Redis;
use Moose;
extends 'Tatsumaki::Application';

has config => (is => 'rw', isa => 'HashRef', lazy => 1, default => sub { });

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
        [   '/q/(.*)'       => h('presque::RestQueueHandler'),
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

presque - a redis based message queue

=head1 SYNOPSIS

=head1 DESCRIPTION

presque is a message queue system based on Tatsumaki and Redis.

The functionalities are inspired by L<RestMQ|http://github.com/gleicon/restmq> and the name by L<resque|http://github.com/defunkt/resque>.

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

=item B<GET /status/(queuename)>

If no queuename is given, return a list of queues. If queuename is given, return the size of the queue and the current policy.

=item B<GET /j/queuename>

return some basic information about a queue.

=item B<GET /control/queuename>

return the status of the queue. A queue have two statues: open or closed. When a queue is closed, no job can be extracted from the queue.

=item B<POST /control/queuename>

change the status of the queue.

=item B<GET /w/(?[worker_id|queue_name])>

If no argument is given, return some stats about workers. If a worker_id is given, return stats about the specific worker. If a queue name is given return stats about the workers on this queue.

=item B<POST /w/queue_name?worker_id>

register a worker on a queue.

=item B<DELETE /w/queue_name?worker_id>

unregister a worker on a queue.

=back

=head1 USAGE

=head2 WORKERS INTERFACE

It's possible for a worker to register itself against presque. This is not required. The main purpose of registering workers is to collect informations about your workers : what are they doing right now, how many jobs have they failed, how many jobs have they processed, ...

=head3 REGISTER A WORKER

To register a worker, a POST request must be made. The content of the POST must be a JSON structure that contains the key B<worker_id>.

    curl -H 'Content-Type: appplication/json' http://localhost:5000/w/foo -d '{"worker_id":"myworker_1"}

The HTTP response is 201, and no content is returned.

=head3 STATISTICS

When a worker is registered, statistics about this worker are collected.

    curl "http://localhost:5000/w/?worker_id=myworker_1" | json_xs -f json -t json-pretty

    {
        "worker_id" : "myworker_1",
        "started_at" : 1273923534,
        "processed" : "0",
        "failed" : "0"
    }

=head3 UNREGISTER A WORKER

When a worker has finished to work, it should unregister itself:

    curl -X DELETE "http://localhost:5000/w/foo?worker_id=myworker_1"

The response HTTP code is 204, and no content is returned.

=head2 JOB INTERFACE

=head3 INSERT A JOB

The B<Content-Type> of the request must be set to B<application/json>. The body of the request must be a valid JSON object.

    curl -H 'Content-Type: application/json' -X POST "http://localhost:5002/q/foo" -d '{"key":"value"}'

It's possible to create delayed jobs (eg: job that will not be run before a defined time in the futur).

    curl -H 'Content-Type: application/json' -X POST "http://localhost:5002/q/foo?delayed="$(expr `date +%s` + 500) -d '{"key":"value"}'

the B<delayed> value should be a date in epoch

=head3 FETCH A JOB

Return a JSON object

   curl http://localhost:5002/q/foo

=head3 PURGE AND DELETE A QUEUE

   curl -X DELETE http://localhost:5002/q/foo

=head2 CHANGE THE POLICY OF A QUEUE

By default, when a queue is created, the status is set to 'open'. When a queue is set to 'stop', no job will be fetched from the queue.

To stop a queue:

    curl -X POST -H 'Content-Type: application/json' -d '{"status":"stop"}' http://localhost:5000/control/foo

    {"response":"updated","queue":"foo"}

To re-open a queue:

    curl -X POST -H 'Content-Type: application/json' -d '{"status":"start"}' http://localhost:5000/control/foo

To fetch the status of a queue:

    curl http://localhost:5000/control/foo

    {"status":"0","queue":"foo"}

=head2 GET SOME STATUS ABOUT A QUEUE

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
