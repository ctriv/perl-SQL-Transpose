package SQL::Translator::Schema::Constraint;

# ----------------------------------------------------------------------
# $Id: Constraint.pm,v 1.2 2003-05-05 04:32:39 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Schema::Constraint - SQL::Translator constraint object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Constraint;
  my $constraint = SQL::Translator::Schema::Constraint->new(
      name   => 'foo',
      fields => [ id ],
      type   => PRIMARY_KEY,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Constraint> is the constraint object.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constants;

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

use constant VALID_TYPE => {
    PRIMARY_KEY, 1,
    UNIQUE,      1,
    CHECK_C,     1,
    FOREIGN_KEY, 1,
};

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema           =  SQL::Translator::Schema::Constraint->new(
      table            => $table,        # the table to which it belongs
      type             => 'foreign_key', # type of table constraint
      name             => 'fk_phone_id', # the name of the constraint
      fields           => 'phone_id',    # the field in the referring table
      reference_fields => 'phone_id',    # the referenced table
      reference_table  => 'phone',       # the referenced fields
      match_type       => 'full',        # how to match
      on_delete_do     => 'cascade',     # what to do on deletes
      on_update_do     => '',            # what to do on updates
  );

=cut

    my ( $self, $config ) = @_;
#        match_type on_delete_do on_update_do
    my @fields = qw[ name type fields reference_fields reference_table table ];

    for my $arg ( @fields ) {
        next unless $config->{ $arg };
        $self->$arg( $config->{ $arg } ) or return;
    }

    return $self;
}

# ----------------------------------------------------------------------
sub deferrable {

=pod

=head2 deferrable

Get or set the whether the constraint is deferrable.  If not defined,
then returns "1."  The argument is evaluated by Perl for True or
False, so the following are eqivalent:

  $deferrable = $field->deferrable(0);
  $deferrable = $field->deferrable('');
  $deferrable = $field->deferrable('0');

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'deferrable'} = $arg ? 1 : 0;
    }

    return defined $self->{'deferrable'} ? $self->{'deferrable'} : 1;
}

# ----------------------------------------------------------------------
sub expression {

=pod

=head2 expression

Gets and set the expression used in a CHECK constraint.

  my $expression = $constraint->expression('...');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # check arg here?
        $self->{'expression'} = $arg;
    }

    return $self->{'expression'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the constraint is valid or not.

  my $ok = $constraint->is_valid;

=cut

    my $self       = shift;
    my $type       = $self->type   or return $self->error('No type');
    my $table      = $self->table  or return $self->error('No table');
    my @fields     = $self->fields or return $self->error('No fields');
    my $table_name = $table->name  or return $self->error('No table name');

    for my $f ( @fields ) {
        next if $table->get_field( $f );
        return $self->error(
            "Constraint references non-existent field '$f' ",
            "in table '$table_name'"
        );
    }

    my $schema = $table->schema or return $self->error(
        'Table ', $table->name, ' has no schema object'
    );

    if ( $type eq FOREIGN_KEY ) {
        return $self->error('Only one field allowed for foreign key')
            if scalar @fields > 1;

        my $ref_table_name  = $self->reference_table or 
            return $self->error('No reference table');

        my $ref_table = $schema->get_table( $ref_table_name ) or
            return $self->error("No table named '$ref_table_name' in schema");

        my @ref_fields = $self->reference_fields or return;

        return $self->error('Only one field allowed for foreign key reference')
            if scalar @ref_fields > 1;

        for my $ref_field ( @ref_fields ) {
            next if $ref_table->get_field( $ref_field );
            return $self->error(
                "Constraint from field(s) ", 
                join(', ', map {qq['$table_name.$_']} @fields),
                " to non-existent field '$ref_table_name.$ref_field'"
            );
        }
    }
    elsif ( $type eq CHECK_C ) {
        return $self->error('No expression for CHECK') unless 
            $self->expression;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the constraint is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

  $constraint->fields('id');
  $constraint->fields('id', 'name');
  $constraint->fields( 'id, name' );
  $constraint->fields( [ 'id', 'name' ] );
  $constraint->fields( qw[ id name ] );

  my @fields = $constraint->fields;

=cut

    my $self   = shift;
    my $fields = UNIVERSAL::isa( $_[0], 'ARRAY' ) 
        ? shift : [ map { s/^\s+|\s+$//g; $_ } map { split /,/ } @_ ];

    if ( @$fields ) {
        my ( %unique, @unique );
        for my $f ( @$fields ) {
            next if $unique{ $f };
            $unique{ $f } = 1;
            push @unique, $f;
        }

        $self->{'fields'} = \@unique;
    }

    return wantarray ? @{ $self->{'fields'} || [] } : $self->{'fields'};
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the constraint's name.

  my $name = $constraint->name('foo');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub on_delete {

=pod

=head2 on_delete

Get or set the constraint's "on delete" action.

  my $action = $constraint->on_delete('cascade');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_delete'} = $arg;
    }

    return $self->{'on_delete'} || '';
}

# ----------------------------------------------------------------------
sub on_update {

=pod

=head2 on_update

Get or set the constraint's "on update" action.

  my $action = $constraint->on_update('no action');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_update'} = $arg;
    }

    return $self->{'on_update'} || '';
}

# ----------------------------------------------------------------------
sub reference_fields {

=pod

=head2 reference_fields

Gets and set the fields in the referred table.  Accepts a string, list or
arrayref; returns an array or array reference.

  $constraint->reference_fields('id');
  $constraint->reference_fields('id', 'name');
  $constraint->reference_fields( 'id, name' );
  $constraint->reference_fields( [ 'id', 'name' ] );
  $constraint->reference_fields( qw[ id name ] );

  my @reference_fields = $constraint->reference_fields;

=cut

    my $self   = shift;
    my $fields = UNIVERSAL::isa( $_[0], 'ARRAY' ) 
        ? shift : [ map { s/^\s+|\s+$//g; $_ } map { split /,/ } @_ ];

    if ( @$fields ) {
        $self->{'reference_fields'} = $fields;
    }

    unless ( ref $self->{'reference_fields'} ) {
        my $table          = $self->table or return $self->error('No table');
        my $schema         = $table->schema or return $self->error('No schema');
        my $ref_table_name = $self->reference_table or 
            return $self->error('No table');
        my $ref_table      = $schema->get_table( $ref_table_name ) or
            return $self->error("Can't find table '$ref_table_name'");

        if ( my $constraint = $ref_table->primary_key ) { 
            $self->{'reference_fields'} = [ $constraint->fields ];
        }
        else {
            $self->error(
                'No reference fields defined and cannot find primary key in ',
                "reference table '$ref_table_name'"
            );
        }
    }

    if ( ref $self->{'reference_fields'} ) {
        return wantarray 
            ?  @{ $self->{'reference_fields'} || [] } 
            :     $self->{'reference_fields'};
    }
    else {
        return wantarray ? () : [];
    }
}

# ----------------------------------------------------------------------
sub reference_table {

=pod

=head2 reference_table

Get or set the table referred to by the constraint.

  my $reference_table = $constraint->reference_table('foo');

=cut

    my $self = shift;
    $self->{'reference_table'} = shift if @_;
    return $self->{'reference_table'} || '';
}


# ----------------------------------------------------------------------
sub type {

=pod

=head2 type

Get or set the constraint's type.

  my $type = $constraint->type( PRIMARY_KEY );

=cut

    my $self = shift;

    if ( my $type = shift ) {
        return $self->error("Invalid constraint type: $type") 
            unless VALID_TYPE->{ $type };
        $self->{'type'} = $type;
    }

    return $self->{'type'} || '';
}


# ----------------------------------------------------------------------
sub table {

=pod

=head2 table

Get or set the field's table object.

  my $table = $field->table;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

# ----------------------------------------------------------------------
sub options {

=pod

=head2 options

Gets or adds to the constraints's options (e.g., "INITIALLY IMMEDIATE").  
Returns an array or array reference.

  $constraint->options('NORELY');
  my @options = $constraint->options;

=cut

    my $self    = shift;
    my $options = UNIVERSAL::isa( $_[0], 'ARRAY' ) 
        ? shift : [ map { s/^\s+|\s+$//g; $_ } map { split /,/ } @_ ];

    push @{ $self->{'options'} }, @$options;

    if ( ref $self->{'options'} ) {
        return wantarray ? @{ $self->{'options'} || [] } : $self->{'options'};
    }
    else {
        return wantarray ? () : [];
    }
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut