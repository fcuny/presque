package presque::ControlHandler;

use Moose;
extends 'Tatsumaki::Handler';
with
  qw/presque::Role::QueueName presque::Role::Error presque::Role::Response/;

__PACKAGE__->asynchronous(1);

sub get {
    my ( $self, $queue_name ) = @_;

    return $self->http_error_queue if !$queue_name;

    my $key = $self->_queue_stat($queue_name);
    $self->application->redis->get(
        $key,
        sub {
            my $status = shift;
            $self->finish(
                JSON::encode_json( {
                        queue  => $queue_name,
                        status => $status
                    }
                )
            );
        }
    );
}

sub post {
    my ( $self, $queue_name ) = @_;

    return $self->http_error_queue if !$queue_name;

    my $content = JSON::decode_json( $self->request->input );
    if ( $content->{status} eq 'start' ) {
        $self->_set_status( $queue_name, 1 );
    }
    elsif ( $content->{status} eq 'stop' ) {
        $self->_set_status( $queue_name, 0 );
    }
    else {
        $self->response->code(400);
        $self->finish(
            JSON::encode_json(
                { error => 'invalid status ' . $content->{status} }
            )
        );
    }
}

sub _set_status {
    my ( $self, $queue_name, $status ) = @_;

    my $key = $self->_queue_stat($queue_name);

    $self->application->redis->set(
        $key, 0,
        sub {
            my $res = shift;
            $self->finish(
                JSON::encode_json( {
                        queue  => $queue_name,
                        status => $res
                    }
                )
            );
        }
    );
}

1;
__END__

=head1 NAME

presque::ControlHandler - a redis based message queue

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
