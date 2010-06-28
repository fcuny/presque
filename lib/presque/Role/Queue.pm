package presque::Role::Queue;

use Moose::Role;

sub new_queue {
    my ($self, $queue_name, $lkey) = @_;
    $self->application->redis->sadd('QUEUESET', $lkey);
    my $ckey = $self->_queue_stat($queue_name);
    $self->application->redis->set($ckey, 1);
}

sub push_job {
    my ($self, $queue_name, $lkey, $key, $delayed) = @_;
    my ($method, @args) = ('rpush', $lkey, $key);

    if ($delayed) {
        $method = 'zadd';
        @args = ($queue_name . ':delayed', $delayed, $key);
        $self->application->redis->get(
            $self->_queue_delayed_next($queue_name),
            sub {
                my $val = shift;
                if (!$val || ($val && $val > $delayed)) {
                    $self->application->redis->set(
                        $self->_queue_delayed_next($queue_name), $delayed);
                }
            }
        );
    }
    $self->application->redis->$method(@args,);
}

1;
