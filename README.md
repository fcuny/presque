# presque

  presque - a redis/tatsumaki based message queue

## INSTALLATION

In order to use presque, you will need:

   * [Tatsumaki](http://search.cpan.org/perldoc?Tatsumaki)
   * [Redis](http://code.google.com/p/redis/) (at least version 2.0)
   * [AnyEvent::Redis](http://search.cpan.org/perldoc?AnyEvent::Redis) original lib.
   * [AnyEvent::Redis](http://github.com/franckcuny/AnyEvent-Redis) for Hash support in Redis (required)

## INTRODUCTION

presque is a persistent job queue that uses Redis for storage and Tatsumaki for the interface between workers and Redis.

presque implement a REST interface for communications, and jobs are JSON data structure.

Workers can be written in any language as long as they implement the REST interface. A complete worker exists for Perl presque::worker. Some examples in other languages can be found in the eg directory.

The functionalities are inspired by [RestMQ](http://github.com/gleicon/restmq) and [resque](http://github.com/defunkt/resque).

## HTTP ROUTES

The following HTTP routes are available:

    GET /q/queuename
        gets an object out of the queue

    POST /q/queuename
        insert an object in the queue

    PUT /q/queuename
        re-insert a job after a worker failed to process the job

    DELETE /q/queuename
        purge and delete the queue

    GET /status/
        informations about a queue.

    GET /j/queuename
        return some basic information about a queue.

    GET /control/queuename
        return the status of the queue. A queue have two statues: open or
        closed. When a queue is closed, no job can be extracted from the
        queue.

    POST /control/queuename
        change the status of the queue.

    GET /w/
        some statisctics about a worker

    POST /w/queuename
        register a worker on a queue.

    DELETE /w/queue_name
        unregister a worker on a queue.

## LIBRARIES

  * [Net::Presque](http://github.com/franckcuny/net-presque) - Perl

## AUTHOR

franck cuny <franck@lumberjaph.net>

## SEE ALSO

For a complete description of each routes, refer to presque::WorkerHandler, presque::RestQueueHandler, presque::ControlHandler, presque::JobQueueHandler, presque::StatusHandler.

For a complete worker see presque::worker.

## LICENSE

Copyright 2010 by Linkfluence

<http://linkfluence.net>

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
