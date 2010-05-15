package presque::RestQueueHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
  qw/presque::Role::QueueName presque::Role::Error presque::Role::Response/;

__PACKAGE__->asynchronous(1);

around [qw/put post/] => sub {
    my $orig       = shift;
    my $self       = shift;
    my $queue_name = shift;

    return $self->http_error_queue if (!$queue_name);

    return $self->http_error_content_type
      if (!$self->request->header('Content-Type')
        || $self->request->header('Content-Type') ne 'application/json');

    return $self->http_error("job is missing") if !$self->request->content;

    $self->$orig($queue_name);
};

around [qw/get delete/] => sub {
    my $orig = shift;
    my $self = shift;
    my $queue_name = shift;

    return $self->http_error_queue if (!$queue_name);

    $self->$orig($queue_name);
};

sub get {
    my ($self, $queue_name) = @_;

    my $dkey = $self->_queue_delayed($queue_name);
    my $lkey = $self->_queue($queue_name);

    my $input = $self->request->parameters;
    my $worker_id = $input->{worker_id} if $input && $input->{worker_id};

    $self->application->redis->get(
        $self->_queue_stat($queue_name),
        sub {
            my $status = shift;

            if (defined $status && $status == 0) {
                return $self->http_error_closed_queue();
            }

            $self->application->redis->zrangebyscore(
                $dkey, 0, time,
                sub {
                    my $value = shift;
                    if ($value && scalar @$value) {
                        my $k = shift @$value;
                        $self->application->redis->zrem($dkey, $k);
                        $self->application->redis->get(
                            $k,
                            sub {
                                my $job = shift;
                                $self->_finish_get($job, $queue_name,
                                    $worker_id);
                            }
                        );
                    }
                    else {
                        $self->application->redis->lpop(
                            $lkey,
                            sub {
                                my $value = shift;
                                if ($value) {
                                    $self->application->redis->get(
                                        $value,
                                        sub {
                                            my $job = shift;
                                            $self->_finish_get($job,
                                                $queue_name, $worker_id);
                                        }
                                    );
                                }
                                else {
                                    $self->http_error('no job', 404);
                                }
                            }
                        );
                    }
                }
            );
        }
    );
}

sub post {
    my ($self, $queue_name) = @_;
    $self->_create_job($queue_name);
}

sub put {
    my ($self, $queue_name) = @_;

    my $input = $self->request->parameters;
    my $worker_id = $input->{worker_id} if $input && $input->{worker_id};

    $self->application->redis->incr('failed');
    $self->application->redis->incr($self->_queue_failed($queue_name));
    if ($worker_id) {
        $self->application->redis->incr('failed:' . $worker_id);
    }

    $self->_create_job($queue_name);
}

sub delete {
    my ($self, $queue_name) = @_;

    # XXX delete failed && processed
    my $lkey = $self->_queue($queue_name);
    my $dkey = $self->_queue_delayed($queue_name);

    $self->application->redis->del($lkey);
    $self->application->redis->del($dkey);
    $self->response->code(204);
    $self->finish();
}

sub _finish_get {
    my ($self, $job, $queue_name, $worker_id) = @_;

    $self->application->redis->incr('processed');
    $self->application->redis->incr($self->_queue_processed($queue_name));
    if ($worker_id) {
        $self->application->redis->set(
            $self->_queue_worker($worker_id),
            JSON::encode_json(
                {   queue  => $queue_name,
                    run_at => time()
                }
            )
        );
        $self->application->redis->incr('processed:' . $worker_id);
    }
    $self->finish($job);
}

sub _create_job {
    my ($self, $queue_name) = @_;

    my $p = $self->request->content;

    my $input   = $self->request->parameters;
    my $delayed = $input->{delayed} if $input && $input->{delayed};

    $self->application->redis->incr(
        $self->_queue_uuid($queue_name),
        sub {
            my $uuid = shift;
            my $key = $self->_queue_key($queue_name, $uuid);

            $self->application->redis->set(
                $key, $p,
                sub {
                    my $status_set = shift;
                    my $lkey       = $self->_queue($queue_name);
                    if ($uuid == 1) {
                        $self->application->redis->sadd('QUEUESET', $lkey);
                        my $ckey = $self->_queue_stat($queue_name);
                        $self->application->redis->set($ckey, 1);
                    }
                    $self->_finish_post($lkey, $key, $status_set, $delayed,
                        $queue_name);
                }
            );
        }
    );
}

sub _finish_post {
    my ($self, $lkey, $key, $result, $delayed, $queue_name) = @_;

    my ($method, @args) = ('rpush', $lkey, $key);

    if ($delayed) {
        $method = 'zadd';
        @args = ($queue_name . ':delayed', $delayed, $key);
    }

    $self->application->redis->$method(@args,);
    $self->response->code(201);
    $self->finish();
}

1;
__END__

=head1 NAME

presque::IndexHandler - a redis based message queue

=head1 DESCRIPTION

=head1 METHODS

=head2 get

Get a JSON object out of the queue.

=head2 post

Insert a new job in the queue. The POST request must:

=over 4

=item

have the B<Content-Type> header of the request set to B<application/json>

=item

the B<body> of the request must be a valid JSON object

=back

=head2 delete

Purge and delete the queue.

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
