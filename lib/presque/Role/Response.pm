package presque::Role::Response;

use Moose::Role;

before get => sub {
    (shift)->_set_response_content_type;
};

before put => sub {
    (shift)->_set_response_content_type;
};

before post => sub {
    (shift)->_set_response_content_type;
};

before delete => sub {
    (shift)->_set_response_content_type;
};

sub _set_response_content_type {
    my $self = shift;
    $self->response->header('Content-Type' => 'application/json');
}

1;
