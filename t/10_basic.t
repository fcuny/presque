use strict;
use warnings;

use Test::More;
use Plack::Test;

use JSON;
use HTTP::Request;
use presque;

$Plack::Test::Impl = 'Server';

my $app = presque->app(
    config => {
        redis => {
            host => '127.0.0.1',
            port => 6379
        }
    }
);

my $queue       = 'presque_test';
my $queue_url   = "http://localhost/q/$queue";
my $job_url     = "http://localhost/j/$queue";
my $stat_url    = "http://localhost/stats/";
my $control_url = "http://localhost/control/$queue";

test_psgi $app, sub {
    my $cb = shift;

    # get queue informations
    my $req = HTTP::Request->new( GET => $job_url );
    ok my $res = $cb->($req), 'get info on an empty queue';
    is_deeply JSON::decode_json $res->content, {
        jobs       => undef,
        job_count  => 0,
        queue      => $queue,
        queue_size => 0
      }, 'good job info result';

    # no job in queue
    $req = HTTP::Request->new( GET => $queue_url );
    ok $res = $cb->($req), 'first request done';
    ok !$res->is_success, 'no job for this queue';
    is_deeply JSON::decode_json( $res->content ), { error => "no job" },
      'error message is valid';

    # fail to create a new job
    $req = HTTP::Request->new( POST => $queue_url );
    $req->content( JSON::encode_json( { foo => 'bar' } ) );
    $res = $cb->($req);
    ok !$res->is_success, 'content-type is not set to json';

    # insert a job
    $req->header( 'Content-Type' => 'application/json' );
    $res = $cb->($req);
    ok $res->is_success, 'new job inserted';

    # info about a queue
    $req = HTTP::Request->new( GET => $job_url );
    $res = $cb->($req);
    my $content = JSON::decode_json $res->content;
    ok grep {/presque_test:1/} @{$content->{jobs}}, 'find jobs';

    # delayed job
    ok $cb->( HTTP::Request->new( GET => $queue_url ) ), 'purged jobs';
    $req = HTTP::Request->new(
        POST => $queue_url . '?delayed=' . ( time() + 2 ) );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( JSON::encode_json { foo => 'baz' } );
    ok $res = $cb->($req), 'delayed job inserted';
    $req = HTTP::Request->new( GET => $queue_url );
    $res = $cb->($req);
    ok !$res->is_success, 'no job';
    sleep(2);
    $res = $cb->($req);
    ok $res->is_success, 'job found';
    like $res->content, qr/baz/, 'delayed job';

    # control queue
    $req     = HTTP::Request->new( GET => $control_url );
    $res     = $cb->($req);
    $content = JSON::decode_json $res->content;
    is_deeply $content, {
        status => 1,
        queue  => 'presque_test'
      },
      'queue is open';

    # close queue
    $req = HTTP::Request->new(POST => $control_url);
    $req->content(JSON::encode_json({status => 'stop'}));
    $res = $cb->($req);
    like $res->content, qr/OK/, 'queue status change';

    # status of a closed queue
    $req     = HTTP::Request->new( GET => $control_url );
    $res     = $cb->($req);
    like $res->content, qr/0/, 'queue is closed';

    # can't get job on a stopped queue
    $req = HTTP::Request->new( GET => $queue_url );
    $res = $cb->($req);
    ok !$res->is_success, 'no job for this queue';
};

done_testing;

