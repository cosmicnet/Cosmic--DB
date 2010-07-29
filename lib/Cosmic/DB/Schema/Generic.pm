package Cosmic::DB::Schema::Generic;
use strict;
use warnings;
use Carp;

=pod

=head Base class for generic DDL code routines

=head Methods

=cut

my %type_size_default = (
    varchar => 2000,
    char => 1,
);

my %type_size_max = (
    varchar => 2000,
    char => 255,
);


=item new

    $db_schema = new Cosmic::DB::Schema( $dbh );

=cut

sub new {
    my $class = shift;
    my ( $dbh, $ddlcode ) = @_;
    $ddlcode ||= {};
    my $self = bless { dbh => $dbh, ddlcode => $ddlcode }, $class;
    $self->load_types;
    return $self;
}#sub


=item datatype

Accessor to the data type equivalents

=cut

sub data_type {
    my $self = shift;
    my ( $type, $size ) = @_;
    $type = lc($type);
    croak( 'Size cannot be passed in with type, as TYPE(SIZE)' ) if $type =~ /\(\s*([0-9]+)\s*\)/;
    croak( "Type '$type' is not recognised" ) unless $self->{data_types}->{$type};
    croak( "Type '$type' cannot have size" ) if defined $size && !$type_size_max{$type};
    croak( "Type '$type' max size is $type_size_max{$type}, input $size out of range" ) if defined $size && $size > $type_size_max{$type};
    $size = $type_size_default{$type} if !$size && $type_size_default{$type};
    my $return = $self->{data_types}->{$type};
    $return .= "($size)" if $size;
    return $return;
}#sub


=item producer

Creates the DDL code for the passed DB schema

=cut

sub producer {
    my $self = shift;
    my %options = @_;

    croak( 'Missing schema' ) unless $options{schema};

    $self->{options} = \%options;
    $self->{ddlcode} = {
        tables           => [],
        indexes          => [],
        constraints      => [],
        extras           => [],
        drop_tables      => [],
        drop_indexes     => [],
        drop_constraints => [],
        drop_extras      => [],
        %{ $self->{ddlcode} },
    };

    # loop tables
    while ( my ( $table, $details ) = each %{ $options{schema} } ) {
        push( @{ $self->{ddlcode}->{tables} }, $self->create_table( $table, $details ) );
        push( @{ $self->{ddlcode}->{drop_tables} }, $self->drop_table( $table, $details ) ) if $options{drop};

        # loop indexes
        foreach my $index ( @{ $details->{indexes} } ) {
            push( @{ $self->{ddlcode}->{indexes} }, $self->create_index( $table, $index ) );
            push( @{ $self->{ddlcode}->{drop_indexes} }, $self->drop_index( $table, $index ) ) if $options{drop};
        }#foreach

        # loop constraints
        # foreign keys
        foreach my $constraint_foreign ( @{ $details->{constraints}->{foreign} } ) {
            push( @{ $self->{ddlcode}->{constraints} }, $self->create_constraint_foreign( $table, $constraint_foreign ) );
            push( @{ $self->{ddlcode}->{drop_constraints} }, $self->drop_constraint_foreign( $table, $constraint_foreign ) ) if $options{drop};
        }#foreach

    }#while

    if ( wantarray ) {
        return (
            @{ $self->{ddlcode}->{drop_constraints} },
            @{ $self->{ddlcode}->{drop_extras} },
            @{ $self->{ddlcode}->{drop_indexes} },
            @{ $self->{ddlcode}->{drop_tables} },
            @{ $self->{ddlcode}->{tables} },
            @{ $self->{ddlcode}->{indexes} },
            @{ $self->{ddlcode}->{constraints} },
            @{ $self->{ddlcode}->{extras} },
        );
    }#if
    else {
        my $return;
        $return .=
            join( ";\n\n", @{ $self->{ddlcode}->{drop_tables} } ) . "\n" .
            join( ";\n", @{ $self->{ddlcode}->{drop_indexes} } ) . "\n\n" .
            join( ";\n", @{ $self->{ddlcode}->{drop_constraints} } ) . "\n\n" .
            join( ";\n", @{ $self->{ddlcode}->{drop_extras} } ) if $options{drop};
        $return .=
            join( ";\n\n", @{ $self->{ddlcode}->{tables} } ) . "\n" .
            join( ";\n", @{ $self->{ddlcode}->{indexes} } ) . "\n\n" .
            join( ";\n", @{ $self->{ddlcode}->{constraints} } ) . "\n\n" .
            join( ";\n", @{ $self->{ddlcode}->{extras} } );
        return $return;
    }#else
}#sub


=item qid

Short quote ID

=cut

sub qid {
    my $self = shift;
    return $self->{dbh}->quote_identifier($_[0]);
}#sub


=item create_column

Creates the column code

=cut

sub create_column {
    my $self = shift;
    my $column = shift;
    my $column_code = $self->qid($column->{name}) . ' ';
    $column_code .= $self->data_type( $column->{type}, $column->{size} );
    $column_code .= ' UNIQUE' if $column->{unique};
    $column_code .= ' DEFAULT ' . $self->{dbh}->quote( $column->{default} ) if $column->{default};
    $column_code .= ' NOT NULL' if defined $column->{null} && $column->{null} == 0;
    return $column_code;
}#sub


=item create_primary_key

Creates the primary key code

=cut

sub create_primary_key {
    my $self = shift;
    my $primary_key = shift;
    my $primary_key_code = 'PRIMARY KEY (';
    $primary_key_code .= join(', ', map { $self->qid($_) } @$primary_key );
    $primary_key_code .= ')';
    return $primary_key_code;
}#sub


=item create_index

Creates the index code

=cut

sub create_index {
    my $self = shift;
    my ( $table, $index ) = @_;
    my $indexcode = 'CREATE ';
    $indexcode .= 'UNIQUE ' if $index->{unique};
    $indexcode .= 'INDEX ' . $self->qid( $index->{name} );
    $indexcode .= ' ON ' . $self->qid($table) . ' (';
    $indexcode .= join( ', ', map { $self->qid($_) } @{ $index->{columns} } );
    $indexcode .= ")";
    return $indexcode;
}#sub


=item create_constraint_foreign

Creates the foreign constraint code

=cut

sub create_constraint_foreign {
    my $self = shift;
    my ( $table, $constraint ) = @_;
    my $constraintcode = 'ALTER TABLE ' .$self->qid($table);
    $constraintcode .= ' ADD CONSTRAINT ' . $self->qid( $constraint->{name} );
    $constraintcode .= ' FOREIGN KEY (';
    $constraintcode .= join( ', ', map { $self->qid($_) } @{ $constraint->{columns} } );
    $constraintcode .= ') REFERENCES ' . $self->qid( $constraint->{references}->{table} ) . ' (';
    $constraintcode .= join( ', ', map { $self->qid($_) } @{ $constraint->{references}->{columns} } );
    $constraintcode .= ')';
    $constraintcode .= ' ON DELETE CASCADE' if $constraint->{cascade};
    return $constraintcode;
}#sub


=item drop_table

Creates the drop table code

=cut

sub drop_table {
    my $self = shift;
    my ( $table, $details ) = @_;
    my $tablecode = 'DROP TABLE IF EXISTS ' . $self->qid($table);
    return $tablecode;
}#sub


=item drop_index

Creates the drop index code

=cut

sub drop_index {
    my $self = shift;
    my ( $table, $index ) = @_;
    my $indexcode = 'ALTER TABLE ' . $self->qid($table) . ' DROP INDEX IF EXISTS ' . $self->qid( $index->{name} );
    return $indexcode;
}#sub


1;
