package presque::Role::Error;

use Moose::Role;

sub http_error {
    my ( $self, $msg, $code ) = @_;
    $self->response->code( $code || 400 );
    $self->finish( JSON::encode_json { error => $msg } );
}

sub http_error_queue {
    my $self = shift;
    $self->http_error( 'queue name is missing', 404 );
}

sub http_error_content_type {
    my $self = shift;
    $self->http_error('content-type must be set to application/json');
}

1;

