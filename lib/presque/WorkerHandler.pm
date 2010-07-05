package presque::WorkerHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
    'presque::Role::Error',
    'presque::Role::Response',
    'presque::Role::Queue::Names',
    'presque::Role::Queue::WithQueueName' => {methods => [qw/delete post/]};

__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;

    my $input      = $self->request->parameters;
    my $worker_id  = $input->{worker_id} if $input && $input->{worker_id};
    my $queue_name = $input->{queue_name} if $input && $input->{queue_name};

    if ($queue_name) {
        $self->_get_stats_for_queue($queue_name);
    }
    elsif ($worker_id) {
        $self->_get_stats_for_worker($worker_id);
    }
    else {
        $self->_get_stats_for_workers();
    }
}

sub post {
    my ($self, $queue_name) = @_;

    my $worker_id = $self->request->header('X-presque-workerid');

    return $self->http_error('worker_id is missing') if !$worker_id;

    $self->application->redis->sadd($self->_workers_list, $worker_id);
    $self->application->redis->sadd($self->_workers_on_queue($queue_name), $worker_id);

    $self->application->redis->hset($self->_workers_processed, $worker_id, 0);
    $self->application->redis->hset($self->_workers_failed,    $worker_id, 0);

    $self->response->code(201);
    $self->finish();
}

sub delete {
    my ($self, $queue_name) = @_;

    my $worker_id = $self->request->header('X-presque-workerid');

    return $self->http_error('worker_id is missing') unless $worker_id;

    $self->application->redis->srem($self->_workers_list, $worker_id);
    $self->application->redis->srem($self->_workers_on_queue($queue_name), $worker_id);

    $self->application->redis->hdel($self->_workers_processed, $worker_id, 0);
    $self->application->redis->hdel($self->_workers_failed,    $worker_id, 0);

    $self->response->code(204);
    $self->finish();
}

sub _get_stats_for_queue {
    my ($self, $queue_name) = @_;

    my $desc = {queue_name => $queue_name};

    $self->application->redis->smembers(
        $self->_workers_on_queue($queue_name),
        sub {
            my $list = shift;
            $desc->{workers_list} = $list;
            $self->application->redis->hget(
                $self->_queue_processed,
                $queue_name,
                sub {
                    my $processed = shift;
                    $desc->{processed} = $processed;
                    $self->application->redis->hget(
                        $self->_queue_failed,
                        $queue_name,
                        sub {
                            my $failed = shift;
                            $desc->{failed} = $failed;
                            $self->entity($desc);
                        }
                    );
                }
            );
        }
    );
}

sub _get_stats_for_worker {
    my ($self, $worker_id) = @_;

    my $desc = {worker_id => $worker_id};

    $self->application->redis->hget(
        $self->_worker_processed,
        $worker_id,
        sub {
            my $processed = shift;
            $desc->{processed} = $processed;
            $self->application->redis->hget(
                $self->_worker_failed,
                $worker_id,
                sub {
                    my $failed = shift;
                    $desc->{failed} = $failed;
                    $self->entity($desc);
                }
            );
        }
    );
}

sub _get_stats_for_workers {
    my $self = shift;

    $self->application->redis->smembers(
        $self->_workers_list,
        sub {
            my $list = shift;
            $self->entity($list);
        }
    );
}

1;

=head1 NAME

presque::WorkerHandler

=head1 SYNOPSIS

    # fetch some informations about a worker
    curl "http://localhost:5000/w/?worker_id=worker_1" | json_xs -f json -t json-pretty

    {
        "worker_id" : "worker_1",
        "started_at" : 1273923534,
        "processed" : "0",
        "failed" : "0"
    }

    # to register the worker "worker_1" on the queue "queuename"
    curl -H 'Content-Type: appplication/json' -H 'X-presque-workerid: worker_1' http://localhost:5000/w/queuename

    # to unreg a worker
    curl -X DELETE -H 'X-presque-workerid: worker_1' http://localhost:5000/w/queuename

=head1 DESCRIPTION

It's possible for a worker to register itself against presque. This is not required. The main purpose of registering workers is to collect informations about your workers : what are they doing right now, how many jobs have they failed, how many jobs have they processed, ...

=head2 GET

=over 4

=item path

/w/:queue_name

=item request

query : worker_id OR queue_name OR none

=item response

http code : 200

content_type : application/json

=back

If the query parameter is B<worker_id>, stats about this worker are returned. If the query parameter is B<queue_name>, stats about the workers on this queue are returned. If no query parameter is set, stats about the queue are returned.

=head2 DELETE

=over 4

=item path

/w/:queue_name

=item headers

X-presque-workerid: worker's ID (optional)

=item response

code : 204

content : null

=back

When a worker has finished to work, it should unregister itself. The response HTTP code is 204, and no content is returned.

=head2 POST

Register a worker on a queue.

=over 4

=item path

/w/:queue_name

=item headers

X-presque-workerid: worker's ID

=item response

http code : 201

content : null

=back

To register a worker, a POST request must be made. The header 'X-presque-workerid' must be set, and the value is the worker's ID.

The HTTP response is 201, and no content is returned.

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
