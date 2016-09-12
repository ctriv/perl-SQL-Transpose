package SQL::Transpose::Role::BuildArgs;

=head1 NAME

SQL::Transpose::Role::BuildArgs - Remove undefined constructor arguments

=head1 SYNOPSIS

    package Foo;
    use Moo;
    with qw(SQL::Transpose::Role::BuildArgs);

=head1 DESCRIPTION

This L<Moo::Role> wraps BUILDARGS to remove C<undef> constructor
arguments for backwards compatibility with the old L<Class::Base>-based
L<SQL::Transpose::Schema::Object>.

=cut

use Moo::Role;

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig(@_);

    foreach my $arg (keys %{$args}) {
        delete $args->{$arg} unless defined($args->{$arg});
    }
    return $args;
};

1;
