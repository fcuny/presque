package presque::Role::RequireQueue;

use MooseX::Role::Parameterized;

parameter methods => (
    isa      => 'ArrayRef',
    required => 1,
);

role {
    my $p = shift;

    my $methods = $p->methods;

    foreach my $m (@$methods) {
        around $m => sub {
            my $orig       = shift;
            my $self       = shift;
            my $queue_name = shift;

            return $self->http_error_queue if !$queue_name;

            $self->$orig($queue_name, @_);
        };
    }
};

1;
