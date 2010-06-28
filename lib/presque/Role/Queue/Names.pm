package presque::Role::Queue::Names;

use Moose::Role;

sub _queue {
    my ($self, $queue_name) = @_;
    return $queue_name.':queue';
}

sub _queue_delayed {
    my ($self, $queue_name) = @_;
    return $queue_name.':delayed';
}

sub _queue_delayed_next {
    my ($self, $queue_name) = @_;
    return $queue_name.':delayed:next';
}

sub _queue_policy {
    my ($self, $queue_name) = @_;
    return $queue_name.':queuepolicy';
}

sub _queue_uuid {
    my ($self, $queue_name) = @_;
    return $queue_name.':UUID';
}

sub _queue_uniq {
    my ($self, $queue_name) = @_;
    return $queue_name . ':uniq';
}

sub _queue_key {
    my ($self, $queue_name, $uuid) = @_;
    return $queue_name.':'.$uuid;
}

sub _queue_stat {
    my ($self, $queue_name) = @_;
    return 'queuestat:'.$queue_name;
}

sub _queue_worker {
    my ($self, $worker_name) = @_;
    return 'worker:'.$worker_name;
}

sub _queue_failed {
    my ($self, $queue_name) = @_;
    return 'failed:'.$queue_name;
}

sub _queue_processed {
    my ($self, $queue_name) = @_;
    return 'processed:' . $queue_name;
}

1;
