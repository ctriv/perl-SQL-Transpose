package SQL::Transpose::Producer::PostgreSQL;

=head1 NAME

SQL::Transpose::Producer::PostgreSQL - PostgreSQL producer for SQL::Transpose

=head1 SYNOPSIS

  my $t = SQL::Transpose->new( parser => '...', producer => 'PostgreSQL' );
  $t->translate;

=head1 DESCRIPTION

Creates a DDL suitable for PostgreSQL.  Very heavily based on the Oracle
producer.

Now handles PostGIS Geometry and Geography data types on table definitions.
Does not yet support PostGIS Views.

=cut

use strict;
use warnings;
our ($DEBUG, $WARN);
$DEBUG = 0 unless defined $DEBUG;

use base qw(SQL::Transpose::Producer);
use SQL::Transpose::Schema::Constants;
use SQL::Transpose::Utils qw(debug header_comment parse_dbms_version batch_alter_table_statements normalize_quote_options);
use SQL::Transpose::Generator::DDL::PostgreSQL;
use Data::Dumper;

use constant MAX_ID_LENGTH => 62;

{
    my ($quoting_generator, $nonquoting_generator);

    sub _generator {
        my $self    = shift;
        my $options = shift;
        return $options->{generator} if exists $options->{generator};

        return normalize_quote_options($options)
            ? $quoting_generator ||= SQL::Transpose::Generator::DDL::PostgreSQL->new
            : $nonquoting_generator ||= SQL::Transpose::Generator::DDL::PostgreSQL->new(
            quote_chars => [],
            );
    }
}

my (%translate);

BEGIN {

    %translate = (
        #
        # MySQL types
        #
        double     => 'double precision',
        decimal    => 'numeric',
        int        => 'integer',
        mediumint  => 'integer',
        tinyint    => 'smallint',
        char       => 'character',
        varchar    => 'character varying',
        longtext   => 'text',
        mediumtext => 'text',
        tinytext   => 'text',
        tinyblob   => 'bytea',
        blob       => 'bytea',
        mediumblob => 'bytea',
        longblob   => 'bytea',
        enum       => 'character varying',
        set        => 'character varying',
        datetime   => 'timestamp',
        year       => 'date',

        #
        # Oracle types
        #
        number   => 'integer',
        varchar2 => 'character varying',
        long     => 'text',
        clob     => 'text',

        #
        # Sybase types
        #
        comment => 'text',

        #
        # MS Access types
        #
        memo => 'text',
    );
}
my %truncated;

=pod

=head1 PostgreSQL Create Table Syntax

  CREATE [ [ LOCAL ] { TEMPORARY | TEMP } ] TABLE table_name (
      { column_name data_type [ DEFAULT default_expr ] [ column_constraint [, ... ] ]
      | table_constraint }  [, ... ]
  )
  [ INHERITS ( parent_table [, ... ] ) ]
  [ WITH OIDS | WITHOUT OIDS ]

where column_constraint is:

  [ CONSTRAINT constraint_name ]
  { NOT NULL | NULL | UNIQUE | PRIMARY KEY |
    CHECK (expression) |
    REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL ]
      [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

and table_constraint is:

  [ CONSTRAINT constraint_name ]
  { UNIQUE ( column_name [, ... ] ) |
    PRIMARY KEY ( column_name [, ... ] ) |
    CHECK ( expression ) |
    FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
      [ MATCH FULL | MATCH PARTIAL ] [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

=head1 Create Index Syntax

  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( column [ ops_name ] [, ...] )
      [ WHERE predicate ]
  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( func_name( column [, ... ]) [ ops_name ] )
      [ WHERE predicate ]

=cut

sub produce {
    my $self       = shift;
    my $translator = shift;
    local $DEBUG = $translator->debug;
    local $WARN  = $translator->show_warnings;
    my $no_comments      = $translator->no_comments;
    my $add_drop_table   = $translator->add_drop_table;
    my $schema           = $translator->schema;
    my $pargs            = $translator->producer_args;
    my $postgres_version = parse_dbms_version($pargs->{postgres_version}, 'perl');

    my $generator = $self->_generator({quote_identifiers => $translator->quote_identifiers});

    my @output;
    push @output, header_comment unless ($no_comments);

    my (@table_defs, @fks);
    my %type_defs;
    foreach my $table ($schema->get_tables) {

        my ($table_def, $fks) = $self->create_table(
            $table, {
                generator        => $generator,
                no_comments      => $no_comments,
                postgres_version => $postgres_version,
                add_drop_table   => $add_drop_table,
                type_defs        => \%type_defs,
            }
        );

        push @table_defs, $table_def;
        push @fks,        @$fks;
    }

    foreach my $view ($schema->get_views) {
        push @table_defs,
            $self->create_view(
            $view, {
                postgres_version => $postgres_version,
                add_drop_view    => $add_drop_table,
                generator        => $generator,
                no_comments      => $no_comments,
            }
            );
    }

    foreach my $trigger ($schema->get_triggers) {
        push @table_defs,
            $self->create_trigger(
            $trigger, {
                add_drop_trigger => $add_drop_table,
                generator        => $generator,
                no_comments      => $no_comments,
            }
            );
    }

    push @output, map { "$_;\n\n" } values %type_defs;
    push @output, map { "$_;\n\n" } @table_defs;
    if (@fks) {
        push @output, "--\n-- Foreign Key Definitions\n--\n\n" unless $no_comments;
        push @output, map { "$_;\n\n" } @fks;
    }

    if ($WARN) {
        if (%truncated) {
            warn "Truncated " . keys(%truncated) . " names:\n";
            warn "\t" . join("\n\t", sort keys %truncated) . "\n";
        }
    }

    return wantarray
        ? @output
        : join('', @output);
}

{
    my %global_names;

    sub mk_name {
        my $self          = shift;
        my $basename      = shift || '';
        my $type          = shift || '';
        my $scope         = shift || '';
        my $critical      = shift || '';
        my $basename_orig = $basename;

        my $max_name
            = $type
            ? MAX_ID_LENGTH - (length($type) + 1)
            : MAX_ID_LENGTH;
        $basename = substr($basename, 0, $max_name)
            if length($basename) > $max_name;
        my $name = $type ? "${type}_$basename" : $basename;

        if ($basename ne $basename_orig and $critical) {
            my $show_type = $type ? "+'$type'" : "";
            warn "Truncating '$basename_orig'$show_type to ", MAX_ID_LENGTH, " character limit to make '$name'\n" if $WARN;
            $truncated{$basename_orig} = $name;
        }

        $scope ||= \%global_names;
        if (my $prev = $scope->{$name}) {
            my $name_orig = $name;
            $name .= sprintf("%02d", ++$prev);
            substr($name, MAX_ID_LENGTH - 3) = "00"
                if length($name) > MAX_ID_LENGTH;

            warn "The name '$name_orig' has been changed to ", "'$name' to make it unique.\n" if $WARN;

            $scope->{$name_orig}++;
        }

        $scope->{$name}++;
        return $name;
    }
}

sub is_geometry {
    my $self  = shift;
    my $field = shift;
    return 1 if $field->data_type eq 'geometry';
}

sub is_geography {
    my $self  = shift;
    my $field = shift;
    return 1 if $field->data_type eq 'geography';
}

sub create_table {
    my ($self, $table, $options) = @_;

    my $generator        = $self->_generator($options);
    my $no_comments      = $options->{no_comments} || 0;
    my $add_drop_table   = $options->{add_drop_table} || 0;
    my $postgres_version = $options->{postgres_version} || 0;
    my $type_defs        = $options->{type_defs} || {};

    my $table_name = $table->name or next;
    my $table_name_qt = $generator->quote($table_name);

    my (@comments, @field_defs, @index_defs, @constraint_defs, @fks);

    push @comments, "--\n-- Table: $table_name\n--\n" unless $no_comments;

    if (!$no_comments and my $comments = $table->comments) {
        $comments =~ s/^/-- /mg;
        push @comments, "-- Comments:\n$comments\n--\n";
    }

    #
    # Fields
    #
    foreach my $field ($table->get_fields) {
        push @field_defs,
            $self->create_field(
            $field, {
                generator        => $generator,
                postgres_version => $postgres_version,
                type_defs        => $type_defs,
                constraint_defs  => \@constraint_defs,
            }
            );
    }

    #
    # Index Declarations
    #
    foreach my $index ($table->get_indices) {
        my ($idef, $constraints) = $self->create_index(
            $index, {
                generator => $generator,
            }
        );
        $idef and push @index_defs, $idef;
        push @constraint_defs, @$constraints;
    }

    #
    # Table constraints
    #
    foreach my $c ($table->get_constraints) {
        my ($cdefs, $fks) = $self->create_constraint(
            $c, {
                generator => $generator,
            }
        );
        push @constraint_defs, @$cdefs;
        push @fks,             @$fks;
    }

    my $create_statement = join("\n", @comments);
    if ($add_drop_table) {
        if ($postgres_version >= 8.002) {
            $create_statement .= "DROP TABLE IF EXISTS $table_name_qt CASCADE;\n";
        }
        else {
            $create_statement .= "DROP TABLE $table_name_qt CASCADE;\n";
        }
    }
    my $temporary = $table->extra->{temporary} ? "TEMPORARY " : "";
    $create_statement .= "CREATE ${temporary}TABLE $table_name_qt (\n" . join(",\n", map { "  $_" } @field_defs, @constraint_defs) . "\n)";
    $create_statement .= @index_defs ? ';' : q{};
    $create_statement .= ($create_statement =~ /;$/ ? "\n" : q{}) . join(";\n", @index_defs);

    #
    # Geometry
    #
    if (my @geometry_columns = grep { $self->is_geometry($_) } $table->get_fields) {
        $create_statement .= join(";\n", '', map { $self->drop_geometry_column($_, $options) } @geometry_columns) if $options->{add_drop_table};
        $create_statement .= join(";\n", '', map { $self->add_geometry_column($_, $options) } @geometry_columns);
    }

    return $create_statement, \@fks;
}

sub create_view {
    my ($self, $view, $options) = @_;
    my $generator        = $self->_generator($options);
    my $postgres_version = $options->{postgres_version} || 0;
    my $add_drop_view    = $options->{add_drop_view};

    my $view_name = $view->name;
    debug("PKG: Looking at view '${view_name}'\n");

    my $create = '';
    $create .= "--\n-- View: " . $generator->quote($view_name) . "\n--\n"
        unless $options->{no_comments};
    if ($add_drop_view) {
        if ($postgres_version >= 8.002) {
            $create .= "DROP VIEW IF EXISTS " . $generator->quote($view_name) . ";\n";
        }
        else {
            $create .= "DROP VIEW " . $generator->quote($view_name) . ";\n";
        }
    }
    $create .= 'CREATE';

    if ($options->{or_replace}) {
        $create .= " OR REPLACE";
    }

    my $extra = $view->extra;
    $create .= " TEMPORARY" if exists($extra->{temporary}) && $extra->{temporary};
    $create .= " VIEW " . $generator->quote($view_name);

    if (my @fields = $view->fields) {
        my $field_list = join ', ', map { $generator->quote($_) } @fields;
        $create .= " ( ${field_list} )";
    }

    if (my $sql = $view->sql) {
        $create .= " AS\n    ${sql}\n";
    }

    if ($extra->{check_option}) {
        $create .= ' WITH ' . uc $extra->{check_option} . ' CHECK OPTION';
    }

    return $create;
}

sub drop_view {
    my ($self, $view, $options) = @_;
    my $generator = $self->_generator($options);

    return sprintf('DROP VIEW %s', $generator->quote($view->name));
}

sub alter_view {
    my ($self, $view, $options) = @_;

    $options ||= {};

    my %options = (
        %$options,
        or_replace  => 1,
        no_comments => 1,
    );

    return $self->create_view($view, \%options);
}

{
    my %field_name_scope;

    sub create_field {
        my ($self, $field, $options) = @_;

        my $generator        = $self->_generator($options);
        my $table_name       = $field->table->name;
        my $constraint_defs  = $options->{constraint_defs} || [];
        my $postgres_version = $options->{postgres_version} || 0;
        my $type_defs        = $options->{type_defs} || {};

        $field_name_scope{$table_name} ||= {};
        my $field_name     = $field->name;
        my $field_comments = '';
        if (my $comments = $field->comments) {
            $comments =~ s/(?<!\A)^/  -- /mg;
            $field_comments = "-- $comments\n  ";
        }

        my $field_def = $field_comments . $generator->quote($field_name);

        #
        # Datatype
        #
        my $data_type = lc $field->data_type;
        my %extra     = $field->extra;
        my $list      = $extra{'list'} || [];
        my $commalist = join(', ', map { $self->_quote_string($_) } @$list);

        if ($postgres_version >= 8.003 && $data_type eq 'enum') {
            my $type_name = $extra{'custom_type_name'} || $field->table->name . '_' . $field->name . '_type';
            $field_def .= ' ' . $type_name;
            my $new_type_def = "DROP TYPE IF EXISTS $type_name CASCADE;\n" . "CREATE TYPE $type_name AS ENUM ($commalist)";
            if (!exists $type_defs->{$type_name}) {
                $type_defs->{$type_name} = $new_type_def;
            }
            elsif ($type_defs->{$type_name} ne $new_type_def) {
                die "Attempted to redefine type name '$type_name' as a different type.\n";
            }
        }
        else {
            $field_def .= ' ' . $self->convert_datatype($field);
        }

        #
        # Default value
        #
        $self->_apply_default_value(
            $field,
            \$field_def, [
                'NULL'              => \'NULL',
                'now()'             => 'now()',
                'CURRENT_TIMESTAMP' => 'CURRENT_TIMESTAMP',
            ],
        );

        #
        # Not null constraint
        #
        $field_def .= ' NOT NULL' unless $field->is_nullable;

        #
        # Geometry constraints
        #
        if ($self->is_geometry($field)) {
            foreach ($self->create_geometry_constraints($field, $options)) {
                my ($cdefs, $fks) = $self->create_constraint($_, $options);
                push @$constraint_defs, @$cdefs;
                push @$fks,             @$fks;
            }
        }

        return $field_def;
    }
}

sub create_geometry_constraints {
    my ($self, $field, $options) = @_;

    my $fname = $self->_generator($options)->quote($field);
    my @constraints;
    push @constraints,
        SQL::Transpose::Schema::Constraint->new(
        name       => "enforce_dims_" . $field->name,
        expression => "(ST_NDims($fname) = " . $field->extra->{dimensions} . ")",
        table      => $field->table,
        type       => CHECK_C,
        );

    push @constraints,
        SQL::Transpose::Schema::Constraint->new(
        name       => "enforce_srid_" . $field->name,
        expression => "(ST_SRID($fname) = " . $field->extra->{srid} . ")",
        table      => $field->table,
        type       => CHECK_C,
        );
    push @constraints,
        SQL::Transpose::Schema::Constraint->new(
        name       => "enforce_geotype_" . $field->name,
        expression => "(GeometryType($fname) = " . $self->_quote_string($field->extra->{geometry_type}) . "::text OR $fname IS NULL)",
        table      => $field->table,
        type       => CHECK_C,
        );

    return @constraints;
}

{
    my %index_name;

    sub create_index {
        my ($self, $index, $options) = @_;

        my $generator  = $self->_generator($options);
        my $table_name = $index->table->name;

        my ($index_def, @constraint_defs);

        my $name = $index->name
            || join('_', $table_name, 'idx', ++$index_name{$table_name});

        my $type = $index->type || NORMAL;
        my @fields = $index->fields;
        return unless @fields;

        my $index_using;
        my $index_where;
        foreach my $opt ($index->options) {
            if (ref $opt eq 'HASH') {
                foreach my $key (keys %$opt) {
                    my $value = $opt->{$key};
                    next unless defined $value;
                    if (uc($key) eq 'USING') {
                        $index_using = "USING $value";
                    }
                    elsif (uc($key) eq 'WHERE') {
                        $index_where = "WHERE $value";
                    }
                }
            }
        }

        my $def_start = 'CONSTRAINT ' . $generator->quote($name) . ' ';
        my $field_names = '(' . join(", ", (map { $_ =~ /\(.*\)/ ? $_ : ($generator->quote($_)) } @fields)) . ')';
        if ($type eq PRIMARY_KEY) {
            push @constraint_defs, "${def_start}PRIMARY KEY " . $field_names;
        }
        elsif ($type eq UNIQUE) {
            push @constraint_defs, "${def_start}UNIQUE " . $field_names;
        }
        elsif ($type eq NORMAL) {
            $index_def = 'CREATE INDEX ' . $generator->quote($name) . ' on ' . $generator->quote($table_name) . ' ' . join ' ',
                grep { defined } $index_using, $field_names, $index_where;
        }
        else {
            warn "Unknown index type ($type) on table $table_name.\n"
                if $WARN;
        }

        return $index_def, \@constraint_defs;
    }
}

sub create_constraint {
    my ($self, $c, $options) = @_;

    my $generator  = $self->_generator($options);
    my $table_name = $c->table->name;
    my (@constraint_defs, @fks);

    my $name = $c->name || '';

    my @fields = grep { defined } $c->fields;

    my @rfields = grep { defined } $c->reference_fields;

    next if !@fields && $c->type ne CHECK_C;
    my $def_start = $name ? 'CONSTRAINT ' . $generator->quote($name) . ' ' : '';
    my $field_names = '(' . join(", ", (map { $_ =~ /\(.*\)/ ? $_ : ($generator->quote($_)) } @fields)) . ')';
    if ($c->type eq PRIMARY_KEY) {
        push @constraint_defs, "${def_start}PRIMARY KEY " . $field_names;
    }
    elsif ($c->type eq UNIQUE) {
        push @constraint_defs, "${def_start}UNIQUE " . $field_names;
    }
    elsif ($c->type eq CHECK_C) {
        my $expression = $c->expression;
        push @constraint_defs, "${def_start}CHECK ($expression)";
    }
    elsif ($c->type eq FOREIGN_KEY) {
        my $def
            .= "ALTER TABLE "
            . $generator->quote($table_name)
            . " ADD ${def_start}FOREIGN KEY $field_names"
            . "\n  REFERENCES "
            . $generator->quote($c->reference_table);

        if (@rfields) {
            $def .= ' (' . join(', ', map { $generator->quote($_) } @rfields) . ')';
        }

        if ($c->match_type) {
            $def .= ' MATCH ' . ($c->match_type =~ /full/i) ? 'FULL' : 'PARTIAL';
        }

        if ($c->on_delete) {
            $def .= ' ON DELETE ' . $c->on_delete;
        }

        if ($c->on_update) {
            $def .= ' ON UPDATE ' . $c->on_update;
        }

        if ($c->deferrable) {
            $def .= ' DEFERRABLE';
        }

        push @fks, "$def";
    }

    return \@constraint_defs, \@fks;
}

sub create_trigger {
    my ($self, $trigger, $options) = @_;
    my $generator = $self->_generator($options);

    my @statements;

    push @statements, sprintf('DROP TRIGGER IF EXISTS %s', $generator->quote($trigger->name))
        if $options->{add_drop_trigger};

    my $scope = $trigger->scope || '';
    $scope = " FOR EACH $scope" if $scope;

    push @statements,
        sprintf(
        'CREATE TRIGGER %s %s %s ON %s%s %s',
        $generator->quote($trigger->name),
        $trigger->perform_action_when,
        join(' OR ', @{$trigger->database_events}),
        $generator->quote($trigger->on_table),
        $scope, $trigger->action,
        );

    return @statements;
}

sub convert_datatype {
    my ($self, $field) = @_;

    my @size      = $field->size;
    my $data_type = lc $field->data_type;
    my $array     = $data_type =~ s/\[\]$//;

    if ($data_type eq 'enum') {

        #        my $len = 0;
        #        $len = ($len < length($_)) ? length($_) : $len for (@$list);
        #        my $chk_name = $self->mk_name( $table_name.'_'.$field_name, 'chk' );
        #        push @$constraint_defs,
        #        'CONSTRAINT "$chk_name" CHECK (' . $generator->quote(field_name) .
        #           qq[IN ($commalist))];
        $data_type = 'character varying';
    }
    elsif ($data_type eq 'set') {
        $data_type = 'character varying';
    }
    elsif ($field->is_auto_increment) {
        if ((defined $size[0] && $size[0] > 11) or $data_type eq 'bigint') {
            $data_type = 'bigserial';
        }
        else {
            $data_type = 'serial';
        }
        undef @size;
    }
    else {
        $data_type
            = defined $translate{lc $data_type}
            ? $translate{lc $data_type}
            : $data_type;
    }

    if ($data_type =~ /^time/i || $data_type =~ /^interval/i) {
        if (defined $size[0] && $size[0] > 6) {
            $size[0] = 6;
        }
    }

    if ($data_type eq 'integer') {
        if (defined $size[0] && $size[0] > 0) {
            if ($size[0] > 10) {
                $data_type = 'bigint';
            }
            elsif ($size[0] < 5) {
                $data_type = 'smallint';
            }
            else {
                $data_type = 'integer';
            }
        }
        else {
            $data_type = 'integer';
        }
    }

    my $type_with_size
        = join('|', 'bit', 'varbit', 'character', 'bit varying', 'character varying', 'time', 'timestamp', 'interval', 'numeric', 'float');

    if ($data_type !~ /$type_with_size/) {
        @size = ();
    }

    if (defined $size[0] && $size[0] > 0 && $data_type =~ /^time/i) {
        $data_type =~ s/^(time.*?)( with.*)?$/$1($size[0])/;
        $data_type .= $2 if (defined $2);
    }
    elsif (defined $size[0] && $size[0] > 0) {
        $data_type .= '(' . join(',', @size) . ')';
    }
    if ($array) {
        $data_type .= '[]';
    }

    #
    # Geography
    #
    if ($data_type eq 'geography') {
        $data_type .= '(' . $field->extra->{geography_type} . ',' . $field->extra->{srid} . ')';
    }

    return $data_type;
}

sub alter_field {
    my ($self, $from_field, $to_field, $options) = @_;

    die "Can't alter field in another table"
        if ($from_field->table->name ne $to_field->table->name);

    my $generator = $self->_generator($options);
    my @out;

    # drop geometry column and constraints
    push @out, $self->drop_geometry_column($from_field, $options), $self->drop_geometry_constraints($from_field, $options),
        if $self->is_geometry($from_field);

    # it's necessary to start with rename column cause this would affect
    # all of the following statements which would be broken if do the
    # rename later
    # BUT: drop geometry is done before the rename, cause it work's on the
    # $from_field directly
    push @out,
        sprintf('ALTER TABLE %s RENAME COLUMN %s TO %s', map($generator->quote($_), $to_field->table->name, $from_field->name, $to_field->name,),)
        if ($from_field->name ne $to_field->name);

    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s SET NOT NULL', map($generator->quote($_), $to_field->table->name, $to_field->name),)
        if (!$to_field->is_nullable and $from_field->is_nullable);

    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s DROP NOT NULL', map($generator->quote($_), $to_field->table->name, $to_field->name),)
        if (!$from_field->is_nullable and $to_field->is_nullable);

    my $from_dt = $self->convert_datatype($from_field);
    my $to_dt   = $self->convert_datatype($to_field);
    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s TYPE %s', map($generator->quote($_), $to_field->table->name, $to_field->name), $to_dt,)
        if ($to_dt ne $from_dt);

    my $old_default   = $from_field->default_value;
    my $new_default   = $to_field->default_value;
    my $default_value = $to_field->default_value;

    # fixes bug where output like this was created:
    # ALTER TABLE users ALTER COLUMN column SET DEFAULT ThisIsUnescaped;
    if (ref $default_value eq "SCALAR") {
        $default_value = $$default_value;
    }
    elsif (defined $default_value && $to_dt =~ /^(character|text)/xsmi) {
        $default_value = $self->_quote_string($default_value);
    }

    push @out,
        sprintf(
        'ALTER TABLE %s ALTER COLUMN %s SET DEFAULT %s',
        map($generator->quote($_), $to_field->table->name, $to_field->name,),
        $default_value,
        )
        if (defined $new_default
        && (!defined $old_default || $old_default ne $new_default));

    # fixes bug where removing the DEFAULT statement of a column
    # would result in no change

    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s DROP DEFAULT', map($generator->quote($_), $to_field->table->name, $to_field->name,),)
        if (!defined $new_default && defined $old_default);

    # add geometry column and constraints
    push @out, $self->add_geometry_column($to_field, $options), $self->add_geometry_constraints($to_field, $options),
        if $self->is_geometry($to_field);

    return wantarray ? @out : join(";\n", @out);
}

sub rename_field { alter_field(@_) }

sub add_field {
    my ($self, $new_field, $options) = @_;

    my $out = sprintf(
        'ALTER TABLE %s ADD COLUMN %s',
        $self->_generator($options)->quote($new_field->table->name),
        $self->create_field($new_field, $options)
    );
    $out .= ";\n" . $self->add_geometry_column($new_field, $options) . ";\n" . $self->add_geometry_constraints($new_field, $options)
        if $self->is_geometry($new_field);
    return $out;

}

sub drop_field {
    my ($self, $old_field, $options) = @_;

    my $generator = $self->_generator($options);

    my $out = sprintf('ALTER TABLE %s DROP COLUMN %s', $generator->quote($old_field->table->name), $generator->quote($old_field->name));
    $out .= ";\n" . $self->drop_geometry_column($old_field, $options)
        if $self->is_geometry($old_field);
    return $out;
}

sub add_geometry_column {
    my ($self, $field, $options) = @_;

    return sprintf(
        "INSERT INTO geometry_columns VALUES (%s,%s,%s,%s,%s,%s,%s)",
        map($self->_quote_string($_),
            '',
            $field->table->schema->name,
            $options->{table} ? $options->{table} : $field->table->name,
            $field->name,
            $field->extra->{dimensions},
            $field->extra->{srid},
            $field->extra->{geometry_type},
        ),
    );
}

sub drop_geometry_column {
    my ($self, $field) = @_;

    return sprintf("DELETE FROM geometry_columns WHERE f_table_schema = %s AND f_table_name = %s AND f_geometry_column = %s",
        map($self->_quote_string($_), $field->table->schema->name, $field->table->name, $field->name,),
    );
}

sub add_geometry_constraints {
    my ($self, $field, $options) = @_;

    return join(";\n", map { $self->alter_create_constraint($_, $options) } $self->create_geometry_constraints($field, $options));
}

sub drop_geometry_constraints {
    my ($self, $field, $options) = @_;

    return join(";\n", map { $self->alter_drop_constraint($_, $options) } $self->create_geometry_constraints($field, $options));

}

sub alter_table {
    my ($self, $to_table, $options) = @_;
    my $generator = $self->_generator($options);
    my $out = sprintf('ALTER TABLE %s %s', $generator->quote($to_table->name), $options->{alter_table_action});
    $out .= ";\n" . $options->{geometry_changes} if $options->{geometry_changes};
    return $out;
}

sub rename_table {
    my ($self, $old_table, $new_table, $options) = @_;
    my $generator = $self->_generator($options);
    $options->{alter_table_action} = "RENAME TO " . $generator->quote($new_table);

    my @geometry_changes = map { $self->drop_geometry_column($_, $options), $self->add_geometry_column($_, {%{$options}, table => $new_table}), }
        grep { $self->is_geometry($_) } $old_table->get_fields;

    $options->{geometry_changes} = join(";\n", @geometry_changes) if @geometry_changes;

    return $self->alter_table($old_table, $options);
}

sub alter_create_index {
    my ($self, $index, $options) = @_;
    my $generator = $self->_generator($options);
    my ($idef, $constraints) = $self->create_index($index, $options);
    return $index->type eq NORMAL
        ? $idef
        : sprintf('ALTER TABLE %s ADD %s', $generator->quote($index->table->name), join(q{}, @$constraints));
}

sub alter_drop_index {
    my ($self, $index, $options) = @_;
    return 'DROP INDEX ' . $self->_generator($options)->quote($index->name);
}

sub alter_drop_constraint {
    my ($self, $c, $options) = @_;
    my $generator = $self->_generator($options);

    # attention: Postgres  has a very special naming structure for naming
    # foreign keys and primary keys.  It names them using the name of the
    # table as prefix and fkey or pkey as suffix, concatenated by an underscore
    my $c_name;
    if ($c->name) {

        # Already has a name, just use it
        $c_name = $c->name;
    }
    elsif ($c->type eq FOREIGN_KEY) {

        # Doesn't have a name, and is foreign key, append '_fkey'
        $c_name = $c->table->name . '_' . ($c->fields)[0] . '_fkey';
    }
    elsif ($c->type eq PRIMARY_KEY) {

        # Doesn't have a name, and is primary key, append '_pkey'
        $c_name = $c->table->name . '_pkey';
    }

    return sprintf('ALTER TABLE %s DROP CONSTRAINT %s', map { $generator->quote($_) } $c->table->name, $c_name,);
}

sub alter_create_constraint {
    my ($self, $index, $options) = @_;
    my $generator = $self->_generator($options);
    my ($defs, $fks) = $self->create_constraint($index, $options);

    # return if there are no constraint definitions so we don't run
    # into output like this:
    # ALTER TABLE users ADD ;

    return unless (@{$defs} || @{$fks});
    return $index->type eq FOREIGN_KEY
        ? join(q{}, @{$fks})
        : join(' ', 'ALTER TABLE', $generator->quote($index->table->name), 'ADD', join(q{}, @{$defs}, @{$fks}));
}

sub drop_table {
    my ($self, $table, $options) = @_;
    my $generator = $self->_generator($options);
    my $out       = "DROP TABLE " . $generator->quote($table) . " CASCADE";

    my @geometry_drops = map { $self->drop_geometry_column($_); } grep { $self->is_geometry($_) } $table->get_fields;

    $out .= join(";\n", '', @geometry_drops) if @geometry_drops;
    return $out;
}

sub batch_alter_table {
    my ($self, $table, $diff_hash, $options) = @_;

    # as long as we're not renaming the table we don't need to be here
    if (@{$diff_hash->{rename_table}} == 0) {
        return batch_alter_table_statements($self, $diff_hash, $options);
    }

    # first we need to perform drops which are on old table
    my @sql = batch_alter_table_statements(
        $self, $diff_hash, $options, qw(
            alter_drop_constraint
            alter_drop_index
            drop_field
            )
    );

    # next comes the rename_table
    my $old_table = $diff_hash->{rename_table}[0][0];
    push @sql, $self->rename_table($old_table, $table, $options);

    # for alter_field (and so also rename_field) we need to make sure old
    # field has table name set to new table otherwise calling alter_field dies
    $diff_hash->{alter_field}  = [map { $_->[0]->table($table) && $_ } @{$diff_hash->{alter_field}}];
    $diff_hash->{rename_field} = [map { $_->[0]->table($table) && $_ } @{$diff_hash->{rename_field}}];

    # now add everything else
    push @sql, batch_alter_table_statements(
        $self, $diff_hash, $options, qw(
            add_field
            alter_field
            rename_field
            alter_create_index
            alter_create_constraint
            alter_table
            )
    );

    return @sql;
}

# CREATE [ OR REPLACE ] FUNCTION
#     name ( [ [ argmode ] [ argname ] argtype [ { DEFAULT | = } default_expr ] [, ...] ] )
#     [ RETURNS rettype
#       | RETURNS TABLE ( column_name column_type [, ...] ) ]
#   { LANGUAGE lang_name
#     | WINDOW
#     | IMMUTABLE | STABLE | VOLATILE
#     | CALLED ON NULL INPUT | RETURNS NULL ON NULL INPUT | STRICT
#     | [ EXTERNAL ] SECURITY INVOKER | [ EXTERNAL ] SECURITY DEFINER
#     | COST execution_cost
#     | ROWS result_rows
#     | SET configuration_parameter { TO value | = value | FROM CURRENT }
#     | AS 'definition'
#     | AS 'obj_file', 'link_symbol'
#   } ...
#     [ WITH ( attribute [, ...] ) ]

sub create_procedure {
    my ($self, $procedure, $options) = @_;

    return $self->_create_function($procedure, {or_replace => 0}, $options);
}

sub alter_procedure {
    my ($self, $procedure, $options) = @_;

    return $self->_create_function($procedure, {or_replace => 1}, $options);
}

sub _create_function {
    my ($self, $procedure, $args, $options) = @_;

    my $generator  = $self->_generator($options);
    my $or_replace = $args->{or_replace} ? 'OR REPLACE ' : '';
    my $name       = $generator->quote($procedure->name);
    my $sql        = sprintf('CREATE %sFUNCTION %s (%s) ', $or_replace, $name, join(', ' => map { $generator->quote($_) } $procedure->parameters));

    my @definitions;
    if (my $returns = $procedure->extra('returns')) {
        $returns = $generator->quote($returns);
        push(@definitions, "RETURNS $returns");
    }

    if (my $lang = $procedure->extra('language')) {
        $lang = $generator->quote($lang);
        push(@definitions, "LANGUAGE $lang");
    }

    my $quote_delim    = '$__SQL_TRANS_SEP__$';
    my $implementation = $procedure->sql;
    push(@definitions, "AS $quote_delim\n$implementation\n$quote_delim");

    $sql .= join(' ', @definitions);

    return $sql;
}

sub drop_procedure {
    my ($self, $procedure, $options) = @_;
    my $generator = $self->_generator($options);

    return sprintf('DROP FUNCTION %s (%s)', $generator->quote($procedure->name), join(', ' => map { $generator->quote($_) } $procedure->parameters));
}

1;

# -------------------------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# -------------------------------------------------------------------

=pod

=head1 SEE ALSO

SQL::Transpose, SQL::Transpose::Producer::Oracle.

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut