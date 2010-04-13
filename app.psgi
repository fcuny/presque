#!/usr/bin/perl
use strict;
use warnings;
use lib ('lib');

use presque;
use Plack::Builder;
use YAML::Syck;

my $conf = LoadFile('conf.yaml');
my $app = presque->app( config => $conf );
