package presque::RestQueueBatchHandler;

use JSON;
use Moose;
extends 'presque::RestQueueHandler';

__PACKAGE__->asynchronous(1);

sub put    { (shift)->http_error('PUT is not supported in batch mode'); }
sub delete { (shift)->htttp_error('DELETE is not supported in batch mode'); }

sub _fetch_job {
    my ($self, $queue_name) = @_;

    my $dkey = $self->_queue_delayed($queue_name);

    my $input = $self->request->parameters;
    my $batch_size =
      ($input && $input->{batch_size}) ? $input->{batch_size} : 50;

    $self->application->redis->zrangebyscore(
        $dkey, 0, time,
        sub {
            my $values = shift;
            if ($values && scalar @$values) {
                $self->_get_jobs_from_delay_queue($queue_name, $dkey, $values, $batch_size);
            }
            else {
                $self->_get_jobs_from_queue($queue_name, 0, $batch_size, []);
            }
        }
    );
}

sub _get_jobs_from_delay_queue {
    my ($self, $queue_name, $dkey, $values, $batch_size) = @_;

    my @keys = @$values[0 .. ($batch_size - 1)];
    foreach (@keys) {
        $self->application->redis->zrem($dkey, $_);
    }
    $self->application->redis->mget(
        @keys,
        sub {
            my $jobs = shift;
            $self->_finish_get($queue_name, $jobs);
        }
    );
}

sub _get_jobs_from_queue {
    my ($self, $queue_name, $pos, $batch_size, $jobs) = @_;

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
                        push @$jobs, $job;
                        if (++$pos >= ($batch_size - 1)) {
                            $self->_finish_get($queue_name, $jobs);
                        }
                        else {
                            $self->_get_jobs_from_queue($queue_name, $pos, $batch_size, $jobs);
                        }
                    }
                );
            }elsif(scalar @$jobs) {
                $self->_finish_get($queue_name, $jobs);
            }
            else {
                $self->http_error('no job', 404);
            }
        }
    );
}

sub _update_queue_stats {
    my ($self, $queue_name, $jobs) = @_;

    $self->application->redis->incrby('processed', scalar @$jobs);
    $self->application->redis->incrby($self->_queue_processed($queue_name), scalar @$jobs);
}

sub _update_worker_stats {
    my ($self, $queue_name, $jobs) = @_;

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
        $self->application->redis->incrby('processed:' . $worker_id, scalar @$jobs);
    }
}

sub _create_job {
    my ($self, $queue_name) = @_;

    my $content = JSON::decode_json($self->request->content);
    my $jobs    = $content->{jobs};

    if (ref $jobs ne 'ARRAY') {
        $self->http_error('jobs should be an array of job');
        return;
    }

    my $input = $self->request->parameters;
    my $delayed = $input->{delayed} if $input && $input->{delayed};

    foreach my $job (@$jobs) {
        $job = JSON::encode_json($job);

        $self->application->redis->incr(
            $self->_queue_uuid($queue_name),
            sub {
                my $uuid = shift;
                my $key = $self->_queue_key($queue_name, $uuid);
                $self->application->redis->set(
                    $key, $job,
                    sub {
                        my $status_set = shift;
                        my $lkey       = $self->_queue($queue_name);

                        $self->new_queue($queue_name, $lkey) if ($uuid == 1);
                        $self->push_job($queue_name, $lkey, $key, $delayed);
                    }
                );
            }
        );
    }

    $self->response->code(201);
    $self->finish();
}

1;
__END__

=head1 NAME

presque::RestQueueBatchHandler

=head1 SYNOPSIS

    # insert a list of jobs
    curl -H 'Content-Type: application/json' -X POST "http://localhost:5000/qb/foo" -d '{jobs:["key":"value"], ["key2":"value2"]}'

    # fetch some jobs
    curl http://localhost:5000/qb/foo

=head1 DESCRIPTION

=head1 METHODS

=head2 get

=head2 post

