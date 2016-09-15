use strict;
use warnings;

use Test::More;

use SQL::Transpose::Generator::DDL::SQLServer;
use SQL::Transpose::Schema::Field;
use SQL::Transpose::Schema::Table;

my $shim = SQL::Transpose::Generator::DDL::SQLServer->new();

is $shim->field(
    SQL::Transpose::Schema::Field->new(
        name      => 'lol',
        data_type => 'int',
    )
    ),
    '[lol] int NULL', 'simple field is generated correctly';

is $shim->field(
    SQL::Transpose::Schema::Field->new(
        name      => 'nice',
        data_type => 'varchar',
        size      => 10,
    )
    ),
    '[nice] varchar(10) NULL', 'sized field is generated correctly';

my $table = SQL::Transpose::Schema::Table->new(
    name => 'mytable',
);

$table->add_field(
    name      => 'myenum',
    data_type => 'enum',
    extra     => {list => [qw(foo ba'r)]},
);

like $shim->table($table),
    qr/\b\QCONSTRAINT [myenum_chk] CHECK ([myenum] IN ('foo','ba''r'))\E/,
    'enum constraint is generated and escaped correctly';

done_testing;

