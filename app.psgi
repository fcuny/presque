#!/usr/bin/perl
use strict;
use warnings;
use lib ('lib');
use File::Basename;
use presque;
use Plack::Builder;
use YAML::Syck;

my $conf = LoadFile('conf.yaml');
my $app = presque->app( config => $conf );

$app->template_path(dirname(__FILE__) . "/templates");
$app->static_path(dirname(__FILE__) . "/static");

$app;
