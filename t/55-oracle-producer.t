#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use warnings;
use Test::More;

use SQL::Transpose::Schema::Constants;
use SQL::Transpose::Schema::Table;
use SQL::Transpose::Schema::Field;
use SQL::Transpose::Schema::Constraint;
use SQL::Transpose::Producer::Oracle;

{
    my $table1 = SQL::Transpose::Schema::Table->new( name => 'table1' );

    my $table1_field1 = $table1->add_field(
        name              => 'fk_col1',
        data_type         => 'NUMBER',
        size              => 6,
        default_value     => undef,
        is_auto_increment => 0,
        is_nullable       => 0,
        is_foreign_key    => 1,
        is_unique         => 0
    );

    my $table1_field2 = $table1->add_field(
        name              => 'fk_col2',
        data_type         => 'VARCHAR',
        size              => 64,
        default_value     => undef,
        is_auto_increment => 0,
        is_nullable       => 0,
        is_foreign_key    => 1,
        is_unique         => 0
    );

    my $table2 = SQL::Transpose::Schema::Table->new( name => 'table2' );

    my $table2_field1 = $table2->add_field(
        name              => 'fk_col1',
        data_type         => 'NUMBER',
        size              => 6,
        default_value     => undef,
        is_auto_increment => 0,
        is_nullable       => 0,
        is_foreign_key    => 0,
        is_unique         => 0
    );

    my $table2_field2 = $table2->add_field(
        name              => 'fk_col2',
        data_type         => 'VARCHAR',
        size              => 64,
        default_value     => undef,
        is_auto_increment => 0,
        is_nullable       => 0,
        is_foreign_key    => 0,
        is_unique         => 0
    );

    my $constraint1 = $table1->add_constraint(
        name             => 'foo',
        fields           => [qw/ fk_col1 fk_col2 /],
        reference_fields => [qw/ fk_col1 fk_col2 /],
        reference_table  => 'table2',
        type             => FOREIGN_KEY,
    );

    my ($table1_def, $fk1_def, $trigger1_def,
        $index1_def, $constraint1_def
    ) = SQL::Transpose::Producer::Oracle::create_table($table1);

    is_deeply(
        $fk1_def,
        [   'ALTER TABLE table1 ADD CONSTRAINT table1_fk_col1_fk_col2_fk FOREIGN KEY (fk_col1, fk_col2) REFERENCES table2 (fk_col1, fk_col2)'
        ],
        'correct "CREATE CONSTRAINT" SQL'
    );
}

done_testing();
