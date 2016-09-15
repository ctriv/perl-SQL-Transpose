use strict;
use Test::More;
use Test::SQL::Transpose qw(maybe_plan);

BEGIN {
    maybe_plan(1, 'SQL::Transpose::Parser::DBI::Oracle',);
}

use_ok('SQL::Transpose::Parser::DBI::Oracle');

1;
