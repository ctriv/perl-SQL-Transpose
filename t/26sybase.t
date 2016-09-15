use strict;
use Test::More;
use Test::SQL::Transpose qw(maybe_plan);

BEGIN {
    maybe_plan(3, 'SQL::Transpose::Parser::DBI::Sybase',);
}

use_ok('SQL::Transpose::Parser::DBI::Sybase');
use_ok('SQL::Transpose::Parser::Storable');
use_ok('SQL::Transpose::Producer::Storable');

1;

