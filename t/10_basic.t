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

my $queue            = "presque_test";
my $worker_id        = "worker_foo";
my $queue_url        = "http://localhost/q/$queue";
my $queue_batch_url  = "http://localhost/qb/$queue";
my $job_url          = "http://localhost/j/$queue";
my $status_url       = "http://localhost/status/$queue";
my $worker_stats_url = "http://localhost/w/?queue_name=$queue";
my $worker_url       = "http://localhost/w/";
my $control_url      = "http://localhost/control/$queue";

test_psgi $app, sub {
    my $cb = shift;
    my ($req, $res);
    my $content;

    # get queue informations
    $res = get_stats_from_queue($cb);
    is_deeply JSON::decode_json $res->content,
      { job_processed => 0,
        job_count     => 0,
        queue_name    => $queue,
        job_failed    => 0,
      },
      'good job info result';

    # no job in queue
    $res = get_job($cb);
    ok !$res->is_success, 'no job for this queue';
    is_deeply JSON::decode_json($res->content), {error => "no job"},
      'error message is valid';

    # create a new job
    my $job = {foo => "bar"};
    $res = create_job($cb, $job);
    ok $res->is_success, 'new job inserted';

    # info about a queue
    $res = get_stats_from_queue($cb);
    is_deeply JSON::decode_json $res->content,
      { job_count     => 1,
        job_failed    => 0,
        job_processed => 0,
        queue_name    => $queue,
      },
      'valid jobs info';

    # do a basic job
    $res = get_job($cb);
    ok $res->is_success, 'job fetched';
    is_deeply JSON::decode_json $res->content, $job, 'job is good';

    # insert a delayed job
    $res = create_job($cb, {foo => 'baz'}, $queue_url . '?delayed='.(time() + 2));

    # no job to do now
    $res = get_job($cb);
    ok !$res->is_success, 'no job';
    sleep(2);
    $res = get_job($cb);
    ok $res->is_success, 'job found';
    like $res->content, qr/baz/, 'delayed job';

    # control queue
    $res = control_queue($cb);
    is_deeply JSON::decode_json $res->content,
      { status => 1,
        queue  => 'presque_test'
      },
      'queue is open';

    # close queue
    $res = change_queue_status($cb, 'stop');
    like $res->content, qr/updated/, 'queue status change';

    # status of a closed queue
    $res = control_queue($cb);
    like $res->content, qr/0/, 'queue is closed';

    # can't get job on a stopped queue
    $res = get_job($cb);
    ok !$res->is_success, 'no job for this queue';

    # open queue
    $res = change_queue_status($cb, 'start');
    like $res->content, qr/updated/, 'queue status change';

    # batch inserts
    my $jobs = [{foo => 1}, {foo => 2}, {foo => 3}, {foo => 4}];
    $res = create_jobs($cb, $jobs);

    # batch fetch
    $res     = get_jobs($cb);
    $content = JSON::decode_json $res->content;
    is_deeply $jobs, [map { JSON::decode_json $_ } @$content], 'valid jobs';

    # insert uniq job
    $res = create_job($cb, {foo => 1}, $queue_url.'?uniq=a');
    is $res->code, 201, 'new uniq job inserted';
    $res = create_job($cb, {foo => 1}, $queue_url.'?uniq=a');
    like $res->content, qr/job already exists/, 'job already exists';
    is $res->code, 400, 'can\'t insert duplicate uniq job';

    # fetch job
    $res = get_job($cb);
    is_deeply JSON::decode_json $res->content, {foo => 1}, 'fetch a job';

    # no job in queue
    $res = get_job($cb);
    is $res->code, 404, 'no more job in queue';

    # job failed
    $res = failed_job($cb);
    is $res->code, 201, 'valid HTTP code returned';

    # status
    $res = queue_status($cb);
    is_deeply JSON::decode_json $res->content,
      {queue => 'presque_test', size => 1}, 'valid status';

    # worker stats for queue
    $res = workers_stats($cb);
    is_deeply JSON::decode_json $res->content,
      { workers_list => [],
        queue_name   => "presque_test",
        processed    => 7,
        failed       => 1,
      },
      'valid stats for queue';

    ## full process with worker id
    # reg.
    $res = reg_worker($cb);
    is $res->code, 201, 'worker is reg.';

    # create/fetch/mcreate/mfetch/fail/stats
    $res = create_job($cb, $job, $queue_url);
    is $res->code, 201, 'job created';

    $res = get_jobs($cb, $queue_url);
    is $res->code, 200, 'got job';

    $res = workers_stats($cb);
    is_deeply JSON::decode_json $res->content,
      { workers_list => [qw/worker_foo/],
        queue_name   => "presque_test",
        processed    => 9,
        failed       => 1,
      },
      'valid stats for queue';

    # unreg.
    $res = unreg_worker($cb);
    is $res->code, 204, 'worker is unreg.';

    # purge queue
    $res = purge_queue($cb);
    is $res->code, 204, 'queue purge';

    # check purged
};

sub get_stats_from_queue {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => $job_url);
    ok my $res = $cb->($req), 'get info on an empty queue';
    $res;
}

sub get_job {
    my ($cb, $url) = @_;
    $url ||= $queue_url;
    my $req = HTTP::Request->new(GET => $queue_url);
    ok my $res = $cb->($req), 'first request done';
    $res;
}

sub get_jobs {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => $queue_batch_url);
    $req->header('X-presque-workerid' => $worker_id);
    ok my $res = $cb->($req);
    $res;
}

sub create_job {
    my ($cb, $job, $url) = @_;
    $url ||= $queue_url;
    my $req = HTTP::Request->new(POST => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('X-presque-workerid' => $worker_id);
    $req->content(JSON::encode_json($job));
    ok my $res = $cb->($req);
    $res;
}

sub create_jobs {
    my ($cb, $jobs, $url) = @_;
    $url ||= $queue_url;
    my $req = HTTP::Request->new(POST => $queue_batch_url);
    $req->header('Content-Type' => 'application/json');
    $req->content(JSON::encode_json({jobs => $jobs}));
    ok my $res = $cb->($req);
    $res;
}

sub failed_job {
    my ($cb, ) = @_;
    my $req = HTTP::Request->new(PUT => $queue_url);
    $req->header('Content-Type' => 'application/json');
    $req->content(JSON::encode_json({foo => 1}));
    ok my $res = $cb->($req), 'store a failed job';
    $res;
}

sub control_queue {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => $control_url);
    ok my $res = $cb->($req);
    $res;
}

sub change_queue_status {
    my ($cb, $status) = @_;
    my $req = HTTP::Request->new(POST => $control_url);
    $req->content(JSON::encode_json({status => $status}));
    ok my $res = $cb->($req);
    $res;
}

sub queue_status {
    my ($cb, ) = @_;
    my $req = HTTP::Request->new(GET => $status_url);
    ok my $res = $cb->($req);
    $res;
}

sub workers_stats {
    my ($cb, ) = @_;
    my $req = HTTP::Request->new(GET => $worker_stats_url);
    ok my $res = $cb->($req);
    $res;
}

sub reg_worker {
    my ($cb,) = @_;
    my $req = HTTP::Request->new(POST => $worker_url . "$queue");
    $req->header('Content-Type'       => 'application/json');
    $req->header('X-presque-workerid' => $worker_id);
    ok my $res = $cb->($req);
    $res;
}

sub unreg_worker {
    my ($cb, ) = @_;
    my $req = HTTP::Request->new(DELETE => $worker_url.$queue);
    $req->header('X-presque-workerid' => $worker_id);
    ok my $res = $cb->($req);
    $res;
}

sub purge_queue {
    my ($cb, ) = @_;
    my $req = HTTP::Request->new(DELETE => $queue_url);
    ok my $res = $cb->($req);
    $res;
}

done_testing;

