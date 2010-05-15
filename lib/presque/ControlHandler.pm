package presque::ControlHandler;

use JSON;
use Moose;
extends 'Tatsumaki::Handler';

with (
  'presque::Role::QueueName',
  'presque::Role::Error',
  'presque::Role::Response',
  'presque::Role::RequireQueue' => {methods => [qw/get post/]},
);

__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $queue_name) = @_;

    $self->application->redis->get(
        $self->_queue_stat($queue_name),
        sub {
            my $status = shift;
            $self->finish(
                JSON::encode_json(
                    {   queue  => $queue_name,
                        status => $status
                    }
                )
            );
        }
    );
}

sub post {
    my ( $self, $queue_name ) = @_;

    my $content = $self->request->content;

    return $self->http_error('content is missing') if !$content;

    my $json = JSON::decode_json( $content );
    if ( $json->{status} eq 'start' ) {
        $self->_set_status( $queue_name, 1 );
    }
    elsif ( $json->{status} eq 'stop' ) {
        $self->_set_status( $queue_name, 0 );
    }
    else {
        $self->http_error('invalid status '.$content->{status});
    }
}

sub _set_status {
    my ($self, $queue_name, $status) = @_;

    my $key = $self->_queue_stat($queue_name);

    $self->application->redis->set($key, $status);
    $self->finish(
        JSON::encode_json(
            {   queue    => $queue_name,
                response => 'updated',
            }
        )
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
