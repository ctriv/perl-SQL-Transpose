package SQL::Transpose::Producer::XML;

=pod

=head1 NAME

SQL::Transpose::Producer::XML - Alias to XML::SQLFairy producer

=head1 DESCRIPTION

Previous versions of SQL::Transpose included an XML producer, but the
namespace has since been further subdivided.  Therefore, this module is
now just an alias to the XML::SQLFairy producer.

=head1 SEE ALSO

SQL::Transpose::Producer::XML::SQLFairy.

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut

use strict;
use warnings;
our $DEBUG;
$DEBUG = 1 unless defined $DEBUG;

use base 'SQL::Transpose::Producer::XML::SQLFairy';


1;
