package presque::Role::Response;

use Moose::Role;

before finish => sub {
    (shift)->response->header('Content-Type' => 'application/json');
};

sub entity {
    my ($self, $content) = @_;
    $self->finish(JSON::encode_json($content));
}

1;
=head1 NAME

presque::Role::Response

=head1 DESCRIPTION

Set the B<Content-Type> header of the response to 'application/json', and serialize to L<JSON> the body.

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
