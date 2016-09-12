package SQL::Transpose::Parser::Storable;

=head1 NAME

SQL::Transpose::Parser::Storable - parser for Schema objects serialized
    with the Storable module

=head1 SYNOPSIS

  use SQL::Transpose;

  my $translator = SQL::Transpose->new;
  $translator->parser('Storable');

=head1 DESCRIPTION

Slurps in a Schema from a Storable file on disk.  You can then turn
the data into a database tables or graphs.

=cut

use strict;
use warnings;

our $DEBUG;
$DEBUG = 0 unless defined $DEBUG;

use Storable;
use SQL::Transpose::Utils qw(debug normalize_name);

use base qw(Exporter);
our @EXPORT_OK = qw(parse);

sub parse {
    my ($translator, $data) = @_;

    if (defined($data)) {
        $translator->{'schema'} = Storable::thaw($data);
        return 1;
    } elsif (defined($translator->filename)) {
        $translator->{'schema'} = Storable::retrieve($translator->filename);
        return 1;
    }

    return 0;
}

1;

=pod

=head1 SEE ALSO

SQL::Transpose.

=head1 AUTHOR

Paul Harrington E<lt>harringp@deshaw.comE<gt>.

=cut
