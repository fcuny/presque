package presque::RestQueueHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

use JSON;
use YAML::Syck;

sub get {
    my ( $self, $queue_name ) = @_;
    my $lkey = $queue_name . ':queue';
    $self->application->redis->lpop(
        $lkey,
        sub {
            my $value = shift;
            my $qpkey = $queue_name . ':queupolicy';
            if ($value) {
                my $val   = $self->application->redis->get(
                    $value,
                    sub {
                        $self->finish(shift);
                    }
                );
            }else{
                $self->finish(JSON::encode_json({error => "no job"}));
            }
        }
    );
}

sub post {
    my ( $self, $queue_name ) = @_;

    my $p = $self->request->content;

    $self->application->redis->incr(
        $queue_name . ':UUID',
        sub {
            my $uuid = shift;
            my $key  = $queue_name . ':' . $uuid;

            $self->application->redis->set(
                $key, $p,
                sub {
                    my $status_set = shift;
                    my $lkey = $queue_name . ':queue';
                    if ($uuid == 1) {
                        $self->application->redis->sadd(
                            'QUEUESET',
                            $lkey,
                            sub {
                                my $ckey = 'queuestat:' . $queue_name;
                                $self->application->redis->set( $ckey, 1 );
                                $self->_finish_post($lkey, $key, $status_set);
                            }
                        );
                    }else{
                        $self->_finish_post($lkey, $key, $status_set);
                    }
                }
            );
        }
    );
}

sub _finish_post {
    my ($self, $lkey, $key, $result) = @_;
    $self->application->redis->rpush(
        $lkey, $key,
        sub {
            $self->finish($result);
        }
    );
}

sub delete {
    my ($self, $queue_name) = @_;
}

1;
