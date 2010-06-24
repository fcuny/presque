package presque::JobQueueHandler;

use Moose;
extends 'Tatsumaki::Handler';

with
  'presque::Role::Queue::Names',
  'presque::Role::Error',
  'presque::Role::Response',
  'presque::Role::Queue::WithQueueName' => {methods => [qw/get/]};

__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $queue_name) = @_;

    my $key       = $self->_queue($queue_name);
    my $processed = $self->_queue_processed($queue_name);
    my $failed    = $self->_queue_failed($queue_name);

    $self->application->redis->llen(
        $key,
        sub {
            my $size = shift;
            $self->application->redis->mget(
                $processed,
                $failed,
                sub {
                    my $res = shift;
                    $self->entity(
                        {   queue_name    => $queue_name,
                            job_count     => $size,
                            job_processed => $res->[0],
                            job_failed    => $res->[1],
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

presque::JobQueueHandler

=head1 SYNOPSIS

    # grab info from a queue
    curl http://localhost:5000/j/queuename

=head1 DESCRIPTION

Return some informations about a queue.

=head1 METHODS

=head2 GET

=over 4

=item path

/j/:queuename

=item request

=item response

content-type: application/json

code: 200

content : {"queue_name":"foo","job_count":"0","job_processed":"127","job_failed":"37"

=back

=head1 AUTHOR

franck cuny E<lt>franck@lumberjaph.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright 2010 by Linkfluence

L<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
