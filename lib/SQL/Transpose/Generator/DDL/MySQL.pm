package SQL::Transpose::Generator::DDL::MySQL;

=head1 NAME

SQL::Transpose::Generator::DDL::MySQL - A Moo based MySQL DDL generation
engine.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

use Moo;

has quote_chars => (
    is      => 'ro',
    default => sub { +[qw(` `)] }
);

with 'SQL::Transpose::Generator::Role::Quote';

sub name_sep { q(.) }

1;
