package presque::IndexHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;
    $self->render('index.html');
}

1;
__END__

=head1 NAME

presque::IndexHandler - a redis based message queue

=head1 DESCRIPTION

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
