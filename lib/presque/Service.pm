package presque::Service;

use Moose;
extends 'Tatsumaki::Service';
with 'presque::Role::Queue::Names';

has redis => (is => 'rw', isa => 'Object', required => 1);

sub start {
    my $self = shift;
    my $t;
    $t = AE::timer 0, 1, sub {
        scalar $t;
        $self->redis->smembers(
            'QUEUESET',
            sub {
                my $queues = shift;
                foreach my $q (@$queues) {
                    $self->_check_delayed_queue($q);
                }
            }
        );
    };
}

sub _check_delayed_queue {
    my ($self, $queue_name) = @_;

    my $dkey = $self->_queue_delayed($queue_name);

    $self->redis->zrangebyscore(
        $dkey, 0, time,
        sub {
            my $keys = shift;
            foreach my $k (@$keys) {
                $self->redis->zrem($dkey, $k);
                $self->redis->lpush($self->_queue($queue_name), $k);
            }
        }
    );
}

1;
