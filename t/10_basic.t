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

my $queue           = "presque_test";
my $queue_url       = "http://localhost/q/$queue";
my $queue_batch_url = "http://localhost/qb/$queue";
my $job_url         = "http://localhost/j/$queue";
my $status_url      = "http://localhost/status/$queue";
my $worker_url      = "http://localhost/w/$queue";
my $control_url     = "http://localhost/control/$queue";

test_psgi $app, sub {
    my $cb = shift;

    # get queue informations
    my $req = HTTP::Request->new(GET => $job_url);
    ok my $res = $cb->($req), 'get info on an empty queue';
    is_deeply JSON::decode_json $res->content,
      { job_processed => 0,
        job_count     => 0,
        queue_name    => $queue,
        job_failed    => 0,
      },
      'good job info result';

    # no job in queue
    $req = HTTP::Request->new(GET => $queue_url);
    ok $res = $cb->($req), 'first request done';
    ok !$res->is_success, 'no job for this queue';
    is_deeply JSON::decode_json($res->content), {error => "no job"},
      'error message is valid';

    # fail to create a new job
    $req = HTTP::Request->new(POST => $queue_url);
    my $job = {foo => "bar"};
    $req->content(JSON::encode_json($job));
    $res = $cb->($req);
    ok !$res->is_success, 'content-type is not set to json';

    # insert a job
    $req->header('Content-Type' => 'application/json');
    $res = $cb->($req);
    ok $res->is_success, 'new job inserted';

    # info about a queue
    $req = HTTP::Request->new(GET => $job_url);
    $res = $cb->($req);
    my $content = JSON::decode_json $res->content;
    is_deeply $content,
      { job_count     => 1,
        job_failed    => 0,
        job_processed => 0,
        queue_name    => $queue,
      },
      'valid jobs info';

    # do a basic job
    $req = HTTP::Request->new(GET => $queue_url);
    ok $res = $cb->($req), 'get a job';
    ok $res->is_success, 'job fetched';
    is_deeply JSON::decode_json $res->content, $job, 'job is good';

    # insert a delayed job
    $req = HTTP::Request->new(POST => $queue_url . '?delayed=' . (time() + 2));
    $req->header('Content-Type' => 'application/json');
    $req->content(JSON::encode_json({foo => 'baz'}));
    ok $res = $cb->($req), 'delayed job inserted';

    # no job to do now
    $req = HTTP::Request->new(GET => $queue_url);
    $res = $cb->($req);
    ok !$res->is_success, 'no job';
    sleep(2);
    $res = $cb->($req);
    ok $res->is_success, 'job found';
    like $res->content, qr/baz/, 'delayed job';

    # # control queue
    $req     = HTTP::Request->new(GET => $control_url);
    $res     = $cb->($req);
    $content = JSON::decode_json $res->content;
    is_deeply $content,
      { status => 1,
        queue  => 'presque_test'
      },
      'queue is open';

    # close queue
    $req = HTTP::Request->new(POST => $control_url);
    $req->content(JSON::encode_json({status => 'stop'}));
    $res = $cb->($req);
    like $res->content, qr/updated/, 'queue status change';

    # status of a closed queue
    $req = HTTP::Request->new(GET => $control_url);
    $res = $cb->($req);
    like $res->content, qr/0/, 'queue is closed';

    # can't get job on a stopped queue
    $req = HTTP::Request->new(GET => $queue_url);
    $res = $cb->($req);
    ok !$res->is_success, 'no job for this queue';

    # open queue
    $req = HTTP::Request->new(POST => $control_url);
    $req->content(JSON::encode_json({status => 'start'}));
    $res = $cb->($req);
    like $res->content, qr/updated/, 'queue status change';

    # batch inserts
    $req = HTTP::Request->new(POST => $queue_batch_url);
    $req->header('Content-Type' => 'application/json');
    my $jobs = [{foo => 1}, {foo => 2}, {foo => 3}, {foo => 4}];
    $req->content(JSON::encode_json({jobs => $jobs}));
    ok $res = $cb->($req), 'insert a batch of jobs';

    # batch fetch
    $req     = HTTP::Request->new(GET => $queue_batch_url);
    $res     = $cb->($req);
    $content = JSON::decode_json $res->content;
    my @jobs = map { JSON::decode_json $_ } @$content;
    is_deeply $jobs, \@jobs, 'valid jobs';

    # status
    $req = HTTP::Request->new(GET => $status_url);
    $res = $cb->($req);
    is_deeply JSON::decode_json $res->content,
      {queue => 'presque_test', size => 0}, 'valid status';

    # worker stats

    # purge queue
    $req = HTTP::Request->new(DELETE => $queue_url);
    $res = $cb->($req);
    is $res->code, 204, 'queue purge';
};

done_testing;

