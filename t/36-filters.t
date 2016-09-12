#!/usr/bin/perl -w
# vim:filetype=perl

#=============================================================================
# Test Package based filters that oks when called.
package SQL::Transpose::Filter::Ok;
use strict;

sub filter { Test::More::pass(
  'Filter called with args: ' . join ', ', @_
) }

# Hack to allow sqlt to see our module as it wasn't loaded from a .pm
$INC{'SQL/Transpose/Filter/Ok.pm'} = 'lib/SQL/Transpose/Filter/Ok.pm';

#=============================================================================
# SQL::Transpose::Filter::HelloWorld - Test filter in a package
package   # hide from cpan
    SQL::Transpose::Filter::HelloWorld;

use strict;

sub filter {
    my ($schema,%args) = (shift,@_);

    my $greeting = $args{greeting} || "Hello";
    my $newtable = "${greeting}World";
    $schema->add_table( name => $newtable );
}

# Hack to allow sqlt to see our module as it wasn't loaded from a .pm
$INC{'SQL/Transpose/Filter/HelloWorld.pm'}
    = 'lib/SQL/Transpose/Filter/HelloWorld.pm';

#=============================================================================

package main;

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Transpose qw(maybe_plan);

use Data::Dumper;

BEGIN {
    maybe_plan(16, 'Template 2.20', 'Test::Differences',
               'SQL::Transpose::Parser::YAML',
              'SQL::Transpose::Producer::YAML')

}
use Test::Differences;
use SQL::Transpose;

my $in_yaml = qq{--- #YAML:1.0
schema:
  tables:
    person:
      name: person
      fields:
        first_name:
          data_type: foovar
          name: First_Name
};

my $ans_yaml = qq{---
schema:
  procedures: {}
  tables:
    GdayWorld:
      constraints: []
      fields: {}
      indices: []
      name: GdayWorld
      options: []
      order: 3
    HelloWorld:
      constraints: []
      fields: {}
      indices: []
      name: HelloWorld
      options: []
      order: 2
    PERSON:
      constraints: []
      fields:
        first_name:
          data_type: foovar
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: first_name
          order: 1
          size:
            - 0
      indices: []
      name: PERSON
      options: []
      order: 1
  triggers: {}
  views: {}
translator:
  add_drop_table: 0
  filename: ~
  no_comments: 0
  parser_args: {}
  parser_type: SQL::Transpose::Parser::YAML
  producer_args: {}
  producer_type: SQL::Transpose::Producer::YAML
  show_warnings: 1
  trace: 0
};

# Parse the test XML schema
my $obj;
$obj = SQL::Transpose->new(
    debug          => 0,
    show_warnings  => 1,
    parser         => "YAML",
    data           => $in_yaml,
    to             => "YAML",
    filters => [
        # Check they get called ok
        sub {
            pass("Filter 1 called");
            isa_ok($_[0],"SQL::Transpose::Schema", "Filter 1, arg0 ");
            is( $#_, 0, "Filter 1, got no args");
        },
        sub {
            pass("Filter 2 called");
            isa_ok($_[0],"SQL::Transpose::Schema", "Filter 2, arg0 ");
            is( $#_, 0, "Filter 2, got no args");
        },

        # Sub filter with args
        [ sub {
            pass("Filter 3 called");
            isa_ok($_[0],"SQL::Transpose::Schema", "Filter 3, arg0 ");
            is( $#_, 2, "Filter 3, go 2 args");
            is( $_[1], "hello", "Filter 3, arg1=hello");
            is( $_[2], "world", "Filter 3, arg2=world");
        },
        hello => "world" ],

        # Uppercase all the table names.
        sub {
            my $schema = shift;
            foreach ($schema->get_tables) {
                $_->name(uc $_->name);
            }
        },

        # lowercase all the field names.
        sub {
            my $schema = shift;
            foreach ( map { $_->get_fields } $schema->get_tables ) {
                $_->name(lc $_->name);
            }
        },

        # Filter from SQL::Transpose::Filter::*
        'Ok',
        [ 'HelloWorld' ],
        [ 'HelloWorld', greeting => 'Gday' ],
    ],

) or die "Failed to create translator object: ".SQL::Transpose->error;

my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
eq_or_diff $out, $ans_yaml           ,"Output looks right";
