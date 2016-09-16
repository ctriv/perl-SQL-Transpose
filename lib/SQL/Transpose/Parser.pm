package SQL::Transpose::Parser;

use strict;
use warnings;

sub parse {
    my ($self, $tr) = @_;

    return $tr->schema;
}


1;

# ----------------------------------------------------------------------
# Enough! or Too much.
# William Blake
# ----------------------------------------------------------------------

=pod

=head1 NAME

SQL::Transpose::Parser - describes how to write a parser

=head1 DESCRIPTION

Parser modules that get invoked by SQL::Transpose need to implement a
single function: B<parse>.  This function will be called by the
SQL::Transpose instance as $class::parse($tr, $data_as_string), where
$tr is a SQL::Transpose instance.  Other than that, the classes are
free to define any helper functions, or use any design pattern
internally that make the most sense.

When the parser has determined what exists, it will communicate the
structure to the producer through the SQL::Transpose::Schema object.
This object can be retrieved from the translator (the first argument
pass to B<parse>) by calling the B<schema> method:

  my $schema = $tr->schema;

The Schema object has methods for adding tables, fields, indices, etc.
For more information, consult the docs for SQL::Transpose::Schema and
its related modules.  For examples of how this works, examine the
source code for existing SQL::Transpose::Parser::* modules.

=head1 AUTHORS

Ken Youens-Clark, E<lt>kclark@cpan.org<gt>,
darren chamberlain E<lt>darren@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), SQL::Transpose, SQL::Transpose::Schema.

=cut
