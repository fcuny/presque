package presque::Role::Queue::Names;

use Moose::Role;

sub _queue {
    my ($self, $queue_name) = @_;
    return join(':', $queue_name, 'queue');
}

sub _queue_set {
    return 'QUEUESET';
}

sub _queue_delayed {
    my ($self, $queue_name) = @_;
    return join(':', $queue_name, 'delayed');
}

sub _queue_policy {
    my ($self, $queue_name) = @_;
    return join(':', $queue_name, 'queuepolicy');
}

sub _queue_uuid {
    my ($self, $queue_name) = @_;
    return join(':', $queue_name, 'UUID');
}

sub _queue_uniq {
    my ($self, $queue_name,) = @_;
    return join(':', $queue_name, 'uniq');
}

sub _queue_uniq_revert {
    my ($self, $queue_name,) = @_;
    return join(':', 'foo', $queue_name, 'uniq_job');
}

sub _queue_key {
    my ($self, $queue_name, $uuid) = @_;
    return join(':', $queue_name, $uuid);
}

sub _queue_stat {
    my ($self, $queue_name) = @_;
    return join(':', 'queuestat', $queue_name);
}

sub _workers_on_queue {
    my ($self, $queue_name) = @_;
    return join(':', 'workers', $queue_name);
}

sub _workers_list      {"workers"}
sub _workers_processed {"workers:processed"}
sub _workers_failed    {"workers:failed"}

sub _queue_processed   {"processed"}
sub _queue_failed      {"failed"}

1;
