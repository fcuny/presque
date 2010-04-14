package presque::RestQueueHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

use JSON;

before [qw/get post/] => sub {
    my $self = shift;
    $self->response->header('Content-Type' => 'application/json');
};

sub get {
    my ( $self, $queue_name ) = @_;

    if ( !$queue_name ) {
        $self->finish(
            JSON::encode_json( { error => 'queue name is missing' } ) );
        return;
    }

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
                $self->response->code(404);

                $self->finish(JSON::encode_json({error => "no job"}));
            }
        }
    );
}

sub post {
    my ( $self, $queue_name ) = @_;

    if ( !$queue_name ) {
        $self->finish(
            JSON::encode_json( { error => 'queue name is missing' } ) );
        return;
    }

    if ( $self->request->header('Content-Type') ne 'application/json' ) {
        $self->finish(
            JSON::encode_json(
                { error => 'content-type must be application/json' }
            )
        );
        return;
    }

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
                    my $lkey       = $queue_name . ':queue';
                    if ( $uuid == 1 ) {
                        $self->application->redis->sadd(
                            'QUEUESET',
                            $lkey,
                            sub {
                                my $ckey = 'queuestat:' . $queue_name;
                                $self->application->redis->set( $ckey, 1 );
                                $self->_finish_post( $lkey, $key,
                                    $status_set );
                            }
                        );
                    }
                    else {
                        $self->_finish_post( $lkey, $key, $status_set );
                    }
                }
            );
        }
    );
}

sub delete {
    my ( $self, $queue_name ) = @_;

    if ( !$queue_name ) {
        $self->finish(
            JSON::encode_json( { error => 'queue name is missing' } ) );
        return;
    }

    my $lkey = $queue_name . ':queue';
    $self->application->redis->del(
        $lkey,
        sub {
            my $res = shift;
            $self->finish(
                JSON::encode_json( { queue => $queue_name, status => $res } )
            );
        }
    );
}

sub _finish_post {
    my ($self, $lkey, $key, $result) = @_;
    $self->application->redis->rpush(
        $lkey, $key,
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
