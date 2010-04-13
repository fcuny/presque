package presque;

use Moose;
our $VERSION = '0.01';
extends 'Tatsumaki::Application';

use AnyEvent::Redis;

use presque::RestQueueHandler;
use presque::JobQueueHandler;
use presque::IndexHandler;

has config => (
    is => 'rw', isa => 'HashRef', lazy => 1, default => sub {}
);

has redis => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $r = AnyEvent::Redis->new();
        $r;
    }
);

sub app {
    my ( $class, %args ) = @_;
    my $self = $class->new(
        [
            '/q/(.*)' => 'presque::RestQueueHandler',
            '/j/(.*)' => 'presque::JobQueueHandler',
            '/'   => 'presque::IndexHandler',
        ]
    );
    $self->config( delete $args{config} );
    $self;
}

1;
__END__

=head1 NAME

presque -

=head1 SYNOPSIS

  use presque;

=head1 DESCRIPTION

presque is

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
