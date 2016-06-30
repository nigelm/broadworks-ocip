
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Broadworks/OCIP.pm',
    'lib/Broadworks/OCIP/Deprecated.pm',
    'lib/Broadworks/OCIP/Deprecated.pod',
    'lib/Broadworks/OCIP/Methods.pm',
    'lib/Broadworks/OCIP/Methods.pod',
    'lib/Broadworks/OCIP/Response.pm',
    'lib/Broadworks/OCIP/Throwable.pm',
    'lib/Redcentric/Roles/OCIP.pm',
    't/00-compile.t',
    't/000-report-versions.t'
);

notabs_ok($_) foreach @files;
done_testing;
