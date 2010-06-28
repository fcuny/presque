package presque::RestQueueHandler;

use 5.010;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
  'presque::Role::Queue::Names',
  'presque::Role::Error', 'presque::Role::Response', 'presque::Role::Queue',
  'presque::Role::Queue::WithContent'   => {methods => [qw/put post/]},
  'presque::Role::Queue::WithQueueName' => {methods => [qw/get delete/]};

__PACKAGE__->asynchronous(1);

sub get    { (shift)->_is_queue_opened(shift) }
sub post   { (shift)->_create_job(shift) }
sub put    { (shift)->_failed_job(shift) }
sub delete { (shift)->_purge_queue(shift) }

sub _is_queue_opened {
    my ($self, $queue_name) = @_;

    $self->application->redis->get(
        $self->_queue_stat($queue_name),
        sub {
            my $status = shift;
            if (defined $status && $status == 0) {
                return $self->http_error_queue_is_closed();
            }else{
                return $self->_fetch_job($queue_name);
            }
        }
    );
}

sub _fetch_job {
    my ($self, $queue_name) = @_;

    my $dkey = $self->_queue_delayed($queue_name);

    $self->application->redis->zrangebyscore(
        $dkey, 0, time,
        sub {
            my $value = shift;
            if ($value && scalar @$value) {
                $self->_get_job_from_delay_queue($queue_name, $dkey, $value);
            }
            else {
                $self->_get_job_from_queue($queue_name);
            }
        }
    );
}

sub _get_job_from_delay_queue {
    my ($self, $queue_name, $dkey, $value) = @_;

    my $k = shift @$value;
    $self->application->redis->zrem($dkey, $k);
    $self->application->redis->get(
        $k,
        sub {
            my $job = shift;
            $self->_finish_get($queue_name, $job, $k);
        }
    );
}

sub _get_job_from_queue {
    my ($self, $queue_name) = @_;

    my $lkey = $self->_queue($queue_name);

    $self->application->redis->lpop(
        $lkey,
        sub {
            my $value = shift;
            if ($value) {
                $self->application->redis->get(
                    $value,
                    sub {
                        my $job = shift;
                        $self->_finish_get($queue_name, $job, $value);
                    }
                );
            }
            else {
                $self->http_error('no job', 404);
            }
        }
    );
}

sub _finish_get {
    my ($self, $queue_name, $job, $key) = @_;

    $self->_remove_from_uniq($queue_name, $key);
    $self->_update_queue_stats($queue_name, $job);
    $self->_update_worker_stats($queue_name, $job);
    $self->finish($job);
}

sub _remove_from_uniq {
    my ($self, $queue_name, $key) = @_;

    my @keys;
    if (ref $key) {
        @keys = map {
            $self->_queue_uniq($queue_name, $_)
        } grep {
            defined $_;
        } @$key;
    }
    else {
        push @keys, $self->_queue_uniq($queue_name, $key);
    }

    $self->application->redis->mget(
        @keys,
        sub {
            my $value = shift;
            for my $i (0 .. (@$value - 1)) {
                if (my $key = $value->[$i]) {
                    $self->application->redis->del(
                        $self->_queue_uniq($queue_name, $key));
                    $self->application->redis->del(
                        $self->_queue_uniq($queue_name, $keys[$i]));
                }
            }
        }
    );
}

sub _update_queue_stats {
    my ($self, $queue_name) = @_;

    $self->application->redis->incr('processed');
    $self->application->redis->incr($self->_queue_processed($queue_name));
}

sub _update_worker_stats {
    my ($self, $queue_name) = @_;

    my $input     = $self->request->parameters;
    my $worker_id = $input->{worker_id};

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
}

sub _create_job {
    my ($self, $queue_name) = @_;

    my $p = $self->request->content;

    my $input   = $self->request->parameters;
    my $delayed = $input->{delayed} if $input && $input->{delayed};
    my $uniq    = $input->{uniq} if $input && $input->{uniq};

    if ($uniq) {
        $self->application->redis->get(
            $self->_queue_uniq($queue_name, $uniq),
            sub {
                my $status = shift;
                if ($status) {
                    $self->http_error('job already exists');
                }
                else {
                    $self->_insert_to_queue($queue_name, $p, $delayed, $uniq);
                }
            }
        );
    }
    else {
        $self->_insert_to_queue($queue_name, $p, $delayed);
    }
}

sub _insert_to_queue {
    my ($self, $queue_name, $p, $delayed, $uniq) = @_;

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
                    $self->new_queue($queue_name, $lkey) if ($uuid == 1);
                    if ($uniq) {
                        $self->application->redis->set(
                            $self->_queue_uniq($queue_name, $uniq), $key);
                        $self->application->redis->set(
                            $self->_queue_uniq($queue_name, $key), $uniq);
                    }
                    $self->_finish_post($lkey, $key, $status_set, $delayed,
                        $queue_name);
                }
            );
        }
    );
}

sub _failed_job {
    my ($self, $queue_name) = @_;

    my $input = $self->request->parameters;
    my $worker_id = $input->{worker_id} if $input && $input->{worker_id};

    $self->application->redis->incr('failed');
    $self->application->redis->incr($self->_queue_failed($queue_name));
    $self->application->redis->incr('failed:' . $worker_id) if $worker_id;

    $self->_create_job($queue_name);
}

sub _purge_queue {
    my ($self, $queue_name) = @_;

    # XXX delete failed && processed
    my $lkey = $self->_queue($queue_name);
    my $dkey = $self->_queue_delayed($queue_name);

    $self->application->redis->del($lkey);
    $self->application->redis->del($dkey);
    $self->response->code(204);
    $self->finish();
}

sub _finish_post {
    my ($self, $lkey, $key, $result, $delayed, $queue_name) = @_;

    $self->push_job($queue_name, $lkey, $key, $delayed);
    $self->response->code(201);
    $self->finish();
}

1;
__END__

=head1 NAME

presque::RestQueueHandler

=head1 SYNOPSIS

    # insert a new job
    curl -H 'Content-Type: application/json' -X POST "http://localhost:5000/q/foo" -d '{"key":"value"}'

    # insert a delayed job
    curl -H 'Content-Type: application/json' -X POST "http://localhost:5000/q/foo?delayed="$(expr `date +%s` + 500) -d '{"key":"value"}'

    # fetch a job
    curl http://localhost:5000/q/foo

    # purge and delete all jobs for a queue
    curl -X DELETE http://localhost:5000/q/foo

=head1 DESCRIPTION

=head1 METHODS

=head2 get

=over 4

=item path

/q/:queue_name

=item request

queue_name: [required] name of the queue to use

worker_id: [optional] id of the worker, used for stats

=item response

If the queue is closed: 404

If no job is available in the queue: 404

If a job is available: 200

Content-Type: application/json

=back

If the queue is open, a job will be fetched from the queue and send to the client

=head2 post

=over 4

=item path

/q/:queue_name

=item request

content-type : application/json

content : JSON object

query : delayed, worker_id

delayed : after which date (in epoch) this job should be run

uniq : this job is uniq. The value is the string that will be used to determined if the job is uniq

=item response

code: 201

content : null

=back

The B<Content-Type> of the request must be set to B<application/json>. The body of the request must be a valid JSON object.

It is possible to create delayed jobs (eg: job that will not be run before a defined time in the futur).

the B<delayed> value should be a date in epoch.

=head2 put

=over 4

=item path

/q/:queue_name

=item request

worker_id: [optional] id of the worker, used for stats

=item response

code: 201

content: null

=back

=head2 delete

=over 4

=item path

/q/:queue_name

=item request

=item response

code: 204

content: null

=back

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
