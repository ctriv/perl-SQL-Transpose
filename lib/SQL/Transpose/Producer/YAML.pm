package SQL::Transpose::Producer::YAML;

=head1 NAME

SQL::Transpose::Producer::YAML - A YAML producer for SQL::Transpose

=head1 SYNOPSIS

  use SQL::Transpose;

  my $translator = SQL::Transpose->new(producer => 'YAML');

=head1 DESCRIPTION

This module uses YAML to serialize a schema to a string so that it
can be saved to disk.  Serializing a schema and then calling producers
on the stored can realize significant performance gains when parsing
takes a long time.

=cut

use strict;
use warnings;

use YAML qw(Dump);

sub produce {
    my $self       = shift;
    my $translator = shift;
    my $schema     = $translator->schema;

    return Dump({
        schema => {
            tables => {
                map { ($_->name => $self->view_table($_)) }
                    $schema->get_tables,
            },
            views => {
                map { ($_->name => $self->view_view($_)) }
                    $schema->get_views,
            },
            triggers => {
                map { ($_->name => $self->view_trigger($_)) }
                    $schema->get_triggers,
            },
            procedures => {
                map { ($_->name => $self->view_procedure($_)) }
                    $schema->get_procedures,
            },
        },
        translator => {
            add_drop_table => $translator->add_drop_table,
            filename       => $translator->filename,
            no_comments    => $translator->no_comments,
            parser_args    => $translator->parser_args,
            producer_args  => $translator->producer_args,
            parser_type    => $translator->parser_type,
            producer_type  => $translator->producer_type,
            show_warnings  => $translator->show_warnings,
            trace          => $translator->trace,
        },
        keys %{$schema->extra} ? ('extra' => { $schema->extra } ) : (),
    });
}

sub view_table {
    my $self  = shift;
    my $table = shift;

    return {
        'name'        => $table->name,
        'order'       => $table->order,
        'options'     => $table->options  || [],
        $table->comments ? ('comments'    => [ $table->comments ] ) : (),
        'constraints' => [
            map { $self->view_constraint($_) } $table->get_constraints
        ],
        'indices'     => [
            map { $self->view_index($_) } $table->get_indices
        ],
        'fields'      => {
            map { ($_->name => $self->view_field($_)) }
                $table->get_fields
        },
        keys %{$table->extra} ? ('extra' => { $table->extra } ) : (),
    };
}

sub view_constraint {
    my $self       = shift;
    my $constraint = shift;

    return {
        'deferrable'       => scalar $constraint->deferrable,
        'expression'       => scalar $constraint->expression,
        'fields'           => [ map { ref $_ ? $_->name : $_ } $constraint->field_names ],
        'match_type'       => scalar $constraint->match_type,
        'name'             => scalar $constraint->name,
        'options'          => scalar $constraint->options,
        'on_delete'        => scalar $constraint->on_delete,
        'on_update'        => scalar $constraint->on_update,
        'reference_fields' => [ map { ref $_ ? $_->name : $_ } $constraint->reference_fields ],
        'reference_table'  => scalar $constraint->reference_table,
        'type'             => scalar $constraint->type,
        keys %{$constraint->extra} ? ('extra' => { $constraint->extra } ) : (),
    };
}

sub view_field {
    my $self  = shift;
    my $field = shift;

    return {
        'order'             => scalar $field->order,
        'name'              => scalar $field->name,
        'data_type'         => scalar $field->data_type,
        'size'              => [ $field->size ],
        'default_value'     => scalar $field->default_value,
        'is_nullable'       => scalar $field->is_nullable,
        'is_primary_key'    => scalar $field->is_primary_key,
        'is_unique'         => scalar $field->is_unique,
        $field->is_auto_increment ? ('is_auto_increment' => 1) : (),
        $field->comments ? ('comments' => [ $field->comments ]) : (),
        keys %{$field->extra} ? ('extra' => { $field->extra } ) : (),
    };
}

sub view_procedure {
    my $self      = shift;
    my $procedure = shift;

    return {
        'order'      => scalar $procedure->order,
        'name'       => scalar $procedure->name,
        'sql'        => scalar $procedure->sql,
        'parameters' => scalar $procedure->parameters,
        'owner'      => scalar $procedure->owner,
        'comments'   => scalar $procedure->comments,
        keys %{$procedure->extra} ? ('extra' => { $procedure->extra } ) : (),
    };
}

sub view_trigger {
    my $self    = shift;
    my $trigger = shift;

    return {
        'order'               => scalar $trigger->order,
        'name'                => scalar $trigger->name,
        'perform_action_when' => scalar $trigger->perform_action_when,
        'database_events'     => scalar $trigger->database_events,
        'fields'              => scalar $trigger->fields,
        'on_table'            => scalar $trigger->on_table,
        'action'              => scalar $trigger->action,
        keys %{$trigger->extra} ? ('extra' => { $trigger->extra } ) : (),
    };
}

sub view_view {
    my $self = shift;
    my $view = shift;

    return {
        'order'  => scalar $view->order,
        'name'   => scalar $view->name,
        'sql'    => scalar $view->sql,
        'fields' => scalar $view->fields,
        keys %{$view->extra} ? ('extra' => { $view->extra } ) : (),
    };
}

sub view_index {
    my $self  = shift;
    my $index = shift;

    return {
        'name'      => scalar $index->name,
        'type'      => scalar $index->type,
        'fields'    => scalar $index->fields,
        'options'   => scalar $index->options,
        keys %{$index->extra} ? ('extra' => { $index->extra } ) : (),
    };
}

1;

=head1 SEE ALSO

SQL::Transpose, YAML, http://www.yaml.org/.

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
