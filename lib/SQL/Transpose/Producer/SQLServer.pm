package SQL::Transpose::Producer::SQLServer;

use strict;
use warnings;
our ( $DEBUG, $WARN );
$DEBUG = 1 unless defined $DEBUG;

use SQL::Transpose::Schema::Constants;
use SQL::Transpose::Utils qw(debug header_comment);
use SQL::Transpose::Generator::DDL::SQLServer;

sub produce {
  my $self = shift;
  my $translator = shift;
  SQL::Transpose::Generator::DDL::SQLServer->new(
    add_comments    => !$translator->no_comments,
    add_drop_table => $translator->add_drop_table,
  )->schema($translator->schema)
}

1;

=head1 NAME

SQL::Transpose::Producer::SQLServer - MS SQLServer producer for SQL::Transpose

=head1 SYNOPSIS

  use SQL::Transpose;

  my $t = SQL::Transpose->new( parser => '...', producer => 'SQLServer' );
  $t->translate;

=head1 DESCRIPTION

This is currently a thin wrapper around the nextgen
L<SQL::Transpose::Generator::DDL::SQLServer> DDL maker.

=head1 Extra Attributes

=over 4

=item field.list

List of values for an enum field.

=back

=head1 TODO

 * !! Write some tests !!
 * Reserved words list needs updating to SQLServer.
 * Triggers, Procedures and Views DO NOT WORK


    # Text of view is already a 'create view' statement so no need to
    # be fancy
    foreach ( $schema->get_views ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- View: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
        $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

    # Text of procedure already has the 'create procedure' stuff
    # so there is no need to do anything fancy. However, we should
    # think about doing fancy stuff with granting permissions and
    # so on.
    foreach ( $schema->get_procedures ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- Procedure: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
      $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

=head1 SEE ALSO

L<SQL::Transpose>

=head1 AUTHORS

See the included AUTHORS file:
L<http://search.cpan.org/dist/SQL-Translator/AUTHORS>

=head1 COPYRIGHT

Copyright (c) 2012 the SQL::Transpose L</AUTHORS> as listed above.

=head1 LICENSE

This code is free software and may be distributed under the same terms as Perl
itself.

=cut
