package SQL::Transpose::Parser::XML;

=pod

=head1 NAME

SQL::Transpose::Parser::XML - Alias to XML::SQLFairy parser

=head1 DESCRIPTION

This module is an alias to the XML::SQLFairy parser.

=head1 SEE ALSO

SQL::Transpose::Parser::XML::SQLFairy.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut

use strict;
use warnings;
our $DEBUG;
$DEBUG = 1 unless defined $DEBUG;

use SQL::Transpose::Parser::XML::SQLFairy;

*parse = \&SQL::Transpose::Parser::XML::SQLFairy::parse;

1;
