package presque::WorkerHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with qw/presque::Role::Error/;

__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $queue_name) = @_;

    if ($queue_name) {

    }else{
        
    }

    $self->finish();
}

sub post {
    my ($self, $queue_name) = @_;

    return $self->http_error_queue if !$queue_name;

    my $content   = JSON::decode_json($self->request->content);
    my $worker_id = $content->{worker_id};

    $self->application->redis->sadd("workers",                $worker_id);
    $self->application->redis->sadd("workers:" . $queue_name, $worker_id);
    $self->finish();
}

sub delete {
    my ($self, $queue_name) = @_;

    return $self->http_error_queue if !$queue_name;

    my $input     = $self->request->parameters;
    my $worker_id = $input->{worker_id};

    return $self->http_error('worker_id is missing') unless $worker_id;

    $self->application->redis->srem("worker",                 $worker_id);
    $self->application->redis->srem("workers:" . $queue_name, $worker_id);
    $self->application->redis->clear("processed:" . $worker_id);
    $self->application->redis->clear("failed:" . $worker_id);
    $self->application->redis->delete("workers:" . $worker_id . ":started");
    $self->finish();
}

1;
