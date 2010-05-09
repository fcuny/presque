package presque::RestQueueHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';
with
  qw/presque::Role::QueueName presque::Role::Error presque::Role::Response/;

__PACKAGE__->asynchronous(1);

sub get {
    my ( $self, $queue_name ) = @_;

    return $self->http_error_queue if ( !$queue_name );

    my $dkey = $self->_queue_delayed($queue_name);
    my $lkey = $self->_queue($queue_name);

    $self->application->redis->zrangebyscore(
        $dkey, 0, time,
        sub {
            my $value = shift;
            if ( $value && scalar @$value ) {
                my $k = shift @$value;
                $self->application->redis->zrem(
                    $dkey, $k,
                    sub {
                        $self->application->redis->get(
                            $k,
                            sub {
                                $self->finish(shift);
                            }
                        );
                    }
                );
            }
            else {
                $self->application->redis->lpop(
                    $lkey,
                    sub {
                        my $value = shift;
                        my $qpkey = $self->_queue_policy($queue_name);
                        if ($value) {
                            $self->application->redis->get(
                                $value,
                                sub {
                                    $self->finish(shift);
                                }
                            );
                        }
                        else {
                            $self->http_error('no job', 404);
                        }
                    }
                );
            }
        }
    );
}

sub post {
    my ( $self, $queue_name ) = @_;

    return $self->http_error_queue if ( !$queue_name );

    return $self->http_error_content_type
      if (!$self->request->header('Content-Type')
        || $self->request->header('Content-Type') ne 'application/json' );

    my $input = $self->request->parameters;
    my $delayed = $input->{delayed};

    my $p = $self->request->content;

    $self->application->redis->incr(
        $self->_queue_uuid($queue_name),
        sub {
            my $uuid = shift;
            my $key  = $self->_queue_key($queue_name,  $uuid);

            $self->application->redis->set(
                $key, $p,
                sub {
                    my $status_set = shift;
                    my $lkey       = $self->_queue($queue_name);
                    if ( $uuid == 1 ) {
                        $self->application->redis->sadd(
                            'QUEUESET',
                            $lkey,
                            sub {
                                my $ckey = $self->_queue_stat($queue_name);
                                $self->application->redis->set( $ckey, 1 );
                                $self->_finish_post( $lkey, $key, $status_set,
                                    $delayed, $queue_name );
                            }
                        );
                    }
                    else {
                        $self->_finish_post( $lkey, $key, $status_set,
                            $delayed, $queue_name );
                    }
                }
            );
        }
    );
}

sub delete {
    my ( $self, $queue_name ) = @_;

    return $self->http_error_queue if ( !$queue_name );

    # delete delayed queue
    my $lkey = $self->_queue($queue_name);
    my $dkey = $self->_queue_delayed($queue_name);

    $self->application->redis->del(
        $lkey,
        sub {
            my $res = shift;
            $self->application->redis->del(
                $dkey,
                sub {
                    $self->finish(
                        JSON::encode_json(
                            { queue => $queue_name, status => $res }
                        )
                    );
                }
            );
        }
    );
}

sub _finish_post {
    my ($self, $lkey, $key, $result, $delayed, $queue_name) = @_;

    my ($method, @args) = ('rpush', $lkey, $key);

    if ($delayed) {
        $method = 'zadd';
        @args = ($queue_name.':delayed', $delayed, $key);
    }

    $self->application->redis->$method(
        @args,
        sub {
            $self->finish({status => 'success'});
        }
    );
}

1;
__END__

=head1 NAME

presque::IndexHandler - a redis based message queue

=head1 DESCRIPTION

=head1 METHODS

=head2 get

Get a JSON object out of the queue.

=head2 post

Insert a new job in the queue. The POST request must:

=over 4

=item

have the B<Content-Type> header of the request set to B<application/json>

=item

the B<body> of the request must be a valid JSON object

=back

=head2 delete

Purge and delete the queue.

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
