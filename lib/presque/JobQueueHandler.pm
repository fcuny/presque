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

    $self->application->redis->llen(
        $self->_queue($queue_name),
        sub {
            my $size = shift;
            $self->application->redis->hget(
                $self->_queue_processed,
                $queue_name,
                sub {
                    my $processed = shift;
                    $self->application->redis->hget(
                        $self->_queue_failed,
                        $queue_name,
                        sub {
                            my $failed = shift;
                            $self->entity(
                                {   queue_name    => $queue_name,
                                    job_count     => $size || 0,
                                    job_failed    => $failed || 0,
                                    job_processed => $processed || 0,
                                }
                            );
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

/j/:queue_name

=item request

=item response

content-type: application/json

code: 200

content : {"queue_name":"foo","job_count":"0","job_processed":"127","job_failed":"37"}

=back

This method return some statistics about a queue. The informations are :

=over 2

=item B<queue_name>

name of the queue

=item B<job_count>

how many jobs are in the queue

=item B<job_processed>

how many jobs have been processed so far for this queue

=item B<job_failed>

how many job have been reported as failed for this queue

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
