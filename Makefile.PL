use inc::Module::Install;
name 'presque';
all_from 'lib/presque.pm';
readme_from 'lib/presque.pm';

# requires '';

tests 't/*.t';

build_requires 'Test::More';
use_test_base;
auto_include;
#auto_include_deps;
author_tests 'xt';
auto_set_repository;
WriteAll;
