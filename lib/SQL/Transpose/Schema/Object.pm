package SQL::Transpose::Schema::Object;

=head1 NAME

SQL::Transpose::Schema::Object - Base class for SQL::Transpose schema objects

=head1 SYNOPSIS

    package SQL::Transpose::Schema::Foo;
    use Moo;
    extends 'SQL::Transpose::Schema::Object';

=head1 DESCRIPTION

Base class for Schema objects. A Moo class consuming the following
roles.

=over

=item L<SQL::Transpose::Role::Error>

Provides C<< $obj->error >>, similar to L<Class::Base>.

=item L<SQL::Transpose::Role::BuildArgs>

Removes undefined constructor arguments, for backwards compatibility.

=item L<SQL::Transpose::Schema::Role::Extra>

Provides an C<extra> attribute storing a hashref of arbitrary data.

=item L<SQL::Transpose::Schema::Role::Compare>

Provides an C<< $obj->equals($other) >> method for testing object
equality.

=back

=cut

use Moo 1.000003;

# screw you PAUSE

with qw(
  SQL::Transpose::Role::Error
  SQL::Transpose::Role::BuildArgs
  SQL::Transpose::Schema::Role::Extra
  SQL::Transpose::Schema::Role::Compare
);

1;
