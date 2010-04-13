package presque::IndexHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

use JSON;

sub get {
    my $self = shift;
    # render template
}

1;
