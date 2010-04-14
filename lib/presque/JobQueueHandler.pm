package presque::JobQueueHandler;

use Moose;
extends 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

before [qw/get/] => sub {
    my $self = shift;
    $self->response->header('Content-Type' => 'application/json');
};

sub get {
    my ( $self, $queue_name ) = @_;

    if (!$queue_name) {
        $self->response->code(404);
        $self->finish({error => 'queue name is missing'});
        return;
    }

    my $key = $queue_name . ':queue';

    $self->application->redis->lrange(
        $key, 0, 9,
        sub {
            my $jobs = shift;
            $self->application->redis->llen(
                $key,
                sub {
                    my $size = shift;
                    my $lkey = $queue_name . '*';
                    $self->application->redis->keys(
                        $lkey,
                        sub {
                            my $total = shift;
                            my $stats = {
                                queue      => $queue_name,
                                jobs       => $jobs,
                                job_count  => $size,
                                queue_size => scalar @$total
                            };
                            $self->finish(JSON::encode_json $stats);
                        }
                    );
                }
            );
        }
    );
}

1;
__END__

=head1 NAME

presque::IndexHandler - a redis based message queue

=head1 DESCRIPTION

Return some informations about a queue.

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
