package presque::JobQueueHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

use JSON;

sub get {
    my ($self, $queue_name) = @_;
}

1;
