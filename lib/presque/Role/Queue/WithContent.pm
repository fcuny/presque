package presque::Role::Queue::WithContent;

use MooseX::Role::Parameterized;

parameter methods => (is => 'ro', isa => 'ArrayRef', required => 1);

role {
    my $p = shift;

    my $methods = $p->methods;

    foreach my $m (@$methods) {
        around $m => sub {
            my $orig       = shift;
            my $self       = shift;
            my $queue_name = shift;

            return $self->http_error_queue if (!$queue_name);

            return $self->http_error_content_type
              if (!$self->request->header('Content-Type')
                || $self->request->header('Content-Type') ne
                'application/json');

            return $self->http_error("job is missing")
              if !$self->request->content;

            $self->$orig($queue_name);
        };
    }
};

1;
