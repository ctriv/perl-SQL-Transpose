package SQL::Transpose::Parser::DBI::MySQL;

=head1 NAME

SQL::Transpose::Parser::DBI::MySQL - parser for DBD::mysql

=head1 SYNOPSIS

This module will be invoked automatically by SQL::Transpose::Parser::DBI,
so there is no need to use it directly.

=head1 DESCRIPTION

Uses SQL calls to query database directly for schema rather than parsing
a create file.  Should be much faster for larger schemas.

=cut

use strict;
use warnings;
use SQL::Transpose::Parser::MySQL;


sub parse {
    my ($self, $tr, $dbh) = @_;
    my $schema      = $tr->schema;
    my @table_names = @{$dbh->selectcol_arrayref('show tables')};
    my @skip_tables = defined $tr->parser_args->{skip} ? split(/,/, $tr->parser_args->{skip}) : ();

    $dbh->{'FetchHashKeyName'} = 'NAME_lc';

    my $create = q{};
    foreach my $table_name (@table_names) {
        next if (grep /^$table_name$/, @skip_tables);
        my $sth = $dbh->prepare("show create table " . $dbh->quote_identifier($table_name));
        $sth->execute;
        my $table = $sth->fetchrow_hashref;
        $create .= ($table->{'create table'} || $table->{'create view'}) . ";\n\n";
    }

    SQL::Transpose::Parser::MySQL->parse($tr, $create);

    return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Transpose.

=cut