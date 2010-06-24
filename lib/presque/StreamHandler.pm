package presque::StreamHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with qw/presque::Role::QueueName presque::Role::Response/;

__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $queue_name) = @_;
}

1;
