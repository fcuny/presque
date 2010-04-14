use strict;
use warnings;
use 5.012;

package simple::worker;
use Moose;
extends 'presque::worker';

sub work {
    my ($self, $job) = @_;
    say "job's done";
    ...; # yadda yadda!
    return;
}

package main;
use AnyEvent;

my $worker = simple::worker->new(base_uri => 'http://localhost:5002', queue => 'baz2');

AnyEvent->condvar->recv;
