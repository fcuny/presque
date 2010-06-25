package presque::WorkerHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
    'presque::Role::Error',
    'presque::Role::Response',
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

    my $content   = JSON::decode_json($self->request->content);
    my $worker_id = $content->{worker_id};

    return $self->http_error('worker_id is missing') if !$worker_id;

    $self->application->redis->sadd("workers",                $worker_id);
    $self->application->redis->sadd("workers:" . $queue_name, $worker_id);
    $self->application->redis->set("processed:" . $worker_id, 0);
    $self->application->redis->set("failed:" . $worker_id,    0);
    $self->application->redis->set("workers:" . $worker_id,
        JSON::encode_json({started_at => time, worker_id => $worker_id}));
    $self->response->code(201);
    $self->finish();
}

sub delete {
    my ($self, $queue_name) = @_;

    my $input     = $self->request->parameters;
    my $worker_id = $input->{worker_id};

    return $self->http_error('worker_id is missing') unless $worker_id;

    $self->application->redis->srem("worker",                 $worker_id);
    $self->application->redis->srem("workers:" . $queue_name, $worker_id);
    $self->application->redis->clear("processed:" . $worker_id);
    $self->application->redis->clear("failed:" . $worker_id);
    $self->application->redis->delete("workers:" . $worker_id . ":started");
    $self->response->code(204);
    $self->finish();
}

sub _get_stats_for_worker {
    my ($self, $worker_id) = @_;
    $self->application->redis->mget(
        'workers:' . $worker_id,
        'processed:' . $worker_id,
        'failed:' . $worker_id,
        sub {
            my $res  = shift;
            my $desc = {};
            $desc = JSON::decode_json(shift @$res) if $res->[0];
            $desc->{processed} = $res->[1] || 0;
            $desc->{failed}    = $res->[2] || 0;
            $self->entity($desc);
        }
    );
}

sub _get_stats_for_queue {
    my ($self, $queue_name) = @_;
    $self->_get_smembers('workers:' . $queue_name);
}

sub _get_stats_for_workers {
    my $self = shift;
    $self->_get_smembers('workers');
}

sub _get_smembers {
    my ($self, $key) = @_;
    $self->application->redis->smembers(
        $key,
        sub {
            my $res = shift;
            $self->finish(JSON::encode_json($res));
        }
    );
}

1;

=head1 NAME

presque::WorkerHandler

=head1 SYNOPSIS

    # fetch some informations about a worker
    curl "http://localhost:5000/w/?worker_id=myworker_1" | json_xs -f json -t json-pretty

    {
        "worker_id" : "myworker_1",
        "started_at" : 1273923534,
        "processed" : "0",
        "failed" : "0"
    }
    # to register the worker "worker_1" on the queue "queuename"
    curl -H 'Content-Type: appplication/json' http://localhost:5000/w/queuename -d '{"worker_id":"worker_1"}'

    # to unreg a worker
    curl -X DELETE "http://localhost:5000/w/foo?worker_id=myworker_1"

=head1 DESCRIPTION

It iss possible for a worker to register itself against presque. This is not required. The main purpose of registering workers is to collect informations about your workers : what are they doing right now, how many jobs have they failed, how many jobs have they processed, ...

=head2 GET

=over 4

=item path

/w/queuename

=item request

query : worker_id OR queue_name

=item response

http code : 200

content_type : application/json

=back

When a worker is registered, statistics about this worker are collected.

=head2 DELETE

=over 4

=item path

/w/queuename

=item request

query : worker_id

=item response

code : 204

content : null

=back

When a worker has finished to work, it should unregister itself. The response HTTP code is 204, and no content is returned.

=head2 POST

Register a worker on a queue.

=over 4

=item path

/w/queuename

=item request

content_type : application/json

body : {"worker_id":"worker_1"}

=item response

http code : 201

content : null

=back

To register a worker, a POST request must be made. The content of the POST must be a JSON structure that contains the key B<worker_id> (all other keys will be ignored).

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
