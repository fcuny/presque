#!/usr/bin/perl
use strict;
use Net::Presque;
use AnyEvent::Twitter::Stream;

my $done = AE::cv;

my($user, $password, $method, %args) = @ARGV;

my $presque = Net::Presque->new(api_base_url => 'http://localhost:5000');

my $streamer = AnyEvent::Twitter::Stream->new(
    username => $user,
    password => $password,
    method   => $method || "sample",
    %args,
    on_tweet => sub {
        my $tweet = shift;
        $presque->create_job(queue_name => 'twitter_stream', user => $tweet->{user}{screen_name}, text => $tweet->{text});
    },
    on_error => sub {
        my $error = shift;
        warn "ERROR: $error";
        $done->send;
    },
    on_eof   => sub {
        $done->send;
    },
);

# uncomment to test undef $streamer
# my $t = AE::timer 1, 0, sub { undef $streamer };

$done->recv;
