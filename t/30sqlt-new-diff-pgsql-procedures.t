#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use warnings;
use SQL::Transpose;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use Test::More;
use Test::Differences;
use Test::SQL::Transpose qw(maybe_plan);
use SQL::Transpose::Schema::Constants;
use Storable 'dclone';

plan tests => 5;

use_ok('SQL::Transpose::Diff') or die "Cannot continue\n";

my $tr = SQL::Transpose->new;

my ( $source_schema, $target_schema, $parsed_sql_schema ) = map {
    my $t = SQL::Transpose->new;
    $t->parser( 'YAML' )
      or die $tr->error;
    my $out = $t->translate( catfile($Bin, qw/data diff pgsql/, $_ ) )
      or die $tr->error;

    my $schema = $t->schema;
    unless ( $schema->name ) {
        $schema->name( $_ );
    }
    ($schema);
} (qw( create1.yml create2.yml ));

$target_schema->add_procedure(
    name => 'foo',
    extra => {
        returns => 'trigger',
        language => 'plpgsql'
    },
    parameters => ['arg integer', 'another text'],
    sql => <<'END_OF_SQL',
BEGIN
UPDATE t_test1 SET f_timestamp=NOW() WHERE id=NEW.product_no;
RETURN NEW;
END
END_OF_SQL
);

# Test for differences
my $out = SQL::Transpose::Diff::schema_diff(
    $source_schema,
   'PostgreSQL',
    $target_schema,
   'PostgreSQL',
   {
     ignore_proc_sql => 0,
     producer_args => {
         quote_identifiers => 1,
     }
   }
);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE "added" (
  "id" bigint
);

CREATE FUNCTION foo (arg integer, another text) RETURNS trigger LANGUAGE plpgsql AS $__SQL_TRANS_SEP__$
BEGIN
UPDATE t_test1 SET f_timestamp=NOW() WHERE id=NEW.product_no;
RETURN NEW;
END

$__SQL_TRANS_SEP__$;

ALTER TABLE "employee" DROP CONSTRAINT "FK5302D47D93FE702E";

ALTER TABLE "employee" DROP COLUMN "job_title";

ALTER TABLE "employee" ADD CONSTRAINT "FK5302D47D93FE702E_diff" FOREIGN KEY ("employee_id")
  REFERENCES "person" ("person_id") DEFERRABLE;

ALTER TABLE "old_name" RENAME TO "new_name";

ALTER TABLE "new_name" ADD COLUMN "new_field" integer;

ALTER TABLE "person" DROP CONSTRAINT "UC_age_name";

DROP INDEX "u_name";

ALTER TABLE "person" ADD COLUMN "is_rock_star" smallint DEFAULT 1;

ALTER TABLE "person" ALTER COLUMN "person_id" TYPE serial;

ALTER TABLE "person" ALTER COLUMN "name" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "age" SET DEFAULT 18;

ALTER TABLE "person" ALTER COLUMN "iq" TYPE bigint;

ALTER TABLE "person" ALTER COLUMN "nickname" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "nickname" TYPE character varying(24);

ALTER TABLE "person" RENAME COLUMN "description" TO "physical_description";

ALTER TABLE "person" ADD CONSTRAINT "unique_name" UNIQUE ("name");

ALTER TABLE "person" ADD CONSTRAINT "UC_person_id" UNIQUE ("person_id");

ALTER TABLE "person" ADD CONSTRAINT "UC_age_name" UNIQUE ("age", "name");

DROP TABLE "deleted" CASCADE;


COMMIT;

## END OF DIFF


# Test for differences in the other direction
$target_schema->drop_procedure('foo');
$source_schema->add_procedure(
    name => 'foo',
    extra => {
        returns => 'trigger',
        language => 'plpgsql'
    },
    parameters => ['arg integer', 'another text'],
    sql => <<'END_OF_SQL',
BEGIN
UPDATE t_test1 SET f_timestamp=NOW() WHERE id=NEW.product_no;
RETURN NEW;
END
END_OF_SQL
);



$out = SQL::Transpose::Diff::schema_diff(
    $source_schema,
   'PostgreSQL',
    $target_schema,
   'PostgreSQL',
   {
     ignore_proc_sql => 0,
     producer_args => {
         quote_identifiers => 1,
     }
   }
);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE "added" (
  "id" bigint
);

DROP FUNCTION foo (arg integer, another text);

ALTER TABLE "employee" DROP CONSTRAINT "FK5302D47D93FE702E";

ALTER TABLE "employee" DROP COLUMN "job_title";

ALTER TABLE "employee" ADD CONSTRAINT "FK5302D47D93FE702E_diff" FOREIGN KEY ("employee_id")
  REFERENCES "person" ("person_id") DEFERRABLE;

ALTER TABLE "old_name" RENAME TO "new_name";

ALTER TABLE "new_name" ADD COLUMN "new_field" integer;

ALTER TABLE "person" DROP CONSTRAINT "UC_age_name";

DROP INDEX "u_name";

ALTER TABLE "person" ADD COLUMN "is_rock_star" smallint DEFAULT 1;

ALTER TABLE "person" ALTER COLUMN "person_id" TYPE serial;

ALTER TABLE "person" ALTER COLUMN "name" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "age" SET DEFAULT 18;

ALTER TABLE "person" ALTER COLUMN "iq" TYPE bigint;

ALTER TABLE "person" ALTER COLUMN "nickname" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "nickname" TYPE character varying(24);

ALTER TABLE "person" RENAME COLUMN "description" TO "physical_description";

ALTER TABLE "person" ADD CONSTRAINT "unique_name" UNIQUE ("name");

ALTER TABLE "person" ADD CONSTRAINT "UC_person_id" UNIQUE ("person_id");

ALTER TABLE "person" ADD CONSTRAINT "UC_age_name" UNIQUE ("age", "name");

DROP TABLE "deleted" CASCADE;


COMMIT;

## END OF DIFF


# Test for alters
$target_schema->add_procedure(
    name => 'foo',
    extra => {
        returns => 'trigger',
        language => 'plpgsql'
    },
    parameters => ['arg integer', 'another text'],
    sql => <<'END_OF_SQL',
BEGIN
UPDATE t_test1 SET f_timestamp=CURRENT_DATETIME() WHERE id=NEW.product_no;
RETURN NEW;
END
END_OF_SQL
);


$out = SQL::Transpose::Diff::schema_diff(
    $source_schema,
   'PostgreSQL',
    $target_schema,
   'PostgreSQL',
   {
     ignore_proc_sql => 0,
     producer_args => {
         quote_identifiers => 1,
     }
   }
);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE "added" (
  "id" bigint
);

CREATE OR REPLACE FUNCTION foo (arg integer, another text) RETURNS trigger LANGUAGE plpgsql AS $__SQL_TRANS_SEP__$
BEGIN
UPDATE t_test1 SET f_timestamp=CURRENT_DATETIME() WHERE id=NEW.product_no;
RETURN NEW;
END

$__SQL_TRANS_SEP__$;

ALTER TABLE "employee" DROP CONSTRAINT "FK5302D47D93FE702E";

ALTER TABLE "employee" DROP COLUMN "job_title";

ALTER TABLE "employee" ADD CONSTRAINT "FK5302D47D93FE702E_diff" FOREIGN KEY ("employee_id")
  REFERENCES "person" ("person_id") DEFERRABLE;

ALTER TABLE "old_name" RENAME TO "new_name";

ALTER TABLE "new_name" ADD COLUMN "new_field" integer;

ALTER TABLE "person" DROP CONSTRAINT "UC_age_name";

DROP INDEX "u_name";

ALTER TABLE "person" ADD COLUMN "is_rock_star" smallint DEFAULT 1;

ALTER TABLE "person" ALTER COLUMN "person_id" TYPE serial;

ALTER TABLE "person" ALTER COLUMN "name" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "age" SET DEFAULT 18;

ALTER TABLE "person" ALTER COLUMN "iq" TYPE bigint;

ALTER TABLE "person" ALTER COLUMN "nickname" SET NOT NULL;

ALTER TABLE "person" ALTER COLUMN "nickname" TYPE character varying(24);

ALTER TABLE "person" RENAME COLUMN "description" TO "physical_description";

ALTER TABLE "person" ADD CONSTRAINT "unique_name" UNIQUE ("name");

ALTER TABLE "person" ADD CONSTRAINT "UC_person_id" UNIQUE ("person_id");

ALTER TABLE "person" ADD CONSTRAINT "UC_age_name" UNIQUE ("age", "name");

DROP TABLE "deleted" CASCADE;


COMMIT;

## END OF DIFF



# Test for sameness
$out = SQL::Transpose::Diff::schema_diff(
    $source_schema, 'PostgreSQL', $source_schema, 'PostgreSQL'
);

eq_or_diff($out, <<'## END OF DIFF', "No differences found");
-- Convert schema 'create1.yml' to 'create1.yml':;

-- No differences found;

## END OF DIFF
