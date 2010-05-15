package presque::WorkerHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with('presque::Role::Error',
    'presque::Role::RequireQueue' => {methods => [qw/delete post/]});

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
            my $desc = JSON::decode_json(shift @$res);
            $desc->{processed} = shift @$res;
            $desc->{failed}    = shift @$res;
            $self->finish(JSON::encode_json($desc));
        }
    );
}

sub _get_stats_for_queue {
    my ($self, $queue_name) = @_;
    $self->_get_smembers('workers:'.$queue_name);
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
