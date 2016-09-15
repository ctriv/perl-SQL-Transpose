#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Transpose qw(maybe_plan);

BEGIN {
    maybe_plan(4, 'Template 2.20',
               'Test::Differences',
               'SQL::Transpose::Parser::XML::SQLFairy')
}
use Test::Differences;

use SQL::Transpose;
use FindBin qw/$Bin/;
# Access to test libs. We want Producer/BaseTest.pm from here.
use lib ("$Bin/lib");


# Parse the test XML schema
my $obj;
$obj = SQL::Transpose->new(
    debug          => 0,
    show_warnings  => 0,
    add_drop_table => 1,
    from           => "XML-SQLFairy",
    filename       => "$Bin/data/xml/schema.xml",
    to             => "BaseTest",
);
my $out;

my $expected = <<END;
Hello World
Tables: Basic, Another

Basic
------
Fields: id title description email explicitnulldef explicitemptystring emptytagdef another_id timest

Another
------
Fields: id num

END

lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
eq_or_diff $out, $expected              ,"Output looks right";
