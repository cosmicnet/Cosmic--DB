package Cosmic::DB::Schema::Postgres;
use base 'Cosmic::DB::Schema::Generic';

use strict;
use warnings;

=pod

=head Generate Postgres DDL code


=head Functions

=cut


# Mappings for DB datatypes
# http://developer.postgresql.org/pgdocs/postgres/datatype.html
sub load_types {
    my $self = shift;
    $self->{data_types} = {
    # Numbers

    # range -2^31 (-2,147,483,648) to 2^31-1 (2,147,483,647)
    # precision none
    int     => 'INTEGER',
    # range -32768 to 32767
    smallint => 'SMALLINT',
    # range -9223372036854775808 to 9223372036854775807
    bigint   => 'BIGINT',

    # range - 3.40E + 38 to -1.18E - 38, 0 and 1.18E - 38 to 3.40E + 38
    # presicion none
    # byte 4
    real   => 'REAL',
    # range - 1.79E+308 to -2.23E-308, 0 and 2.23E-308 to 1.79E+308
    # presicion 1 to 53
    # byte 8
    double => 'DOUBLE PRECISION',

    # smallint -32768 to 32767
    # bigint -9223372036854775808 to 9223372036854775807

    # Date

    # range -4713-01-01 through 5874897-12-31
    date      => 'DATE',

    # range 00:00:00 through 24:00:00
    time      => 'TIME',

    # range -4713-01-01 through 5874897-12-31
    # format iso 2004-05-23T14:25:10
    timestamp => 'TIMESTAMP',

    ## Characters
    #
    ## range unclear??
    ## precision unclear??
    #char    => 'CHARACTER',
    ## range unclear??
    ## precision unclear??
    #varchar => 'CHARACTER VARYING',
    ## range unlimited
    ## precision none
    #text    => 'TEXT',

    # Unicode Characters

    # range unclear??
    # precision unclear??
    char    => 'CHARACTER',
    # range unclear??
    # precision unclear??
    varchar => 'CHARACTER VARYING',
    # range unlimited
    # precision none
    text    => 'TEXT',

    # Special

    # serials
    # range 1 to 2147483647
    serial    => 'SERIAL UNIQUE',
    # range 1 to 9223372036854775807
    bigserial => 'BIGSERIAL UNIQUE',
    };
}#sub

# indexes http://developer.postgresql.org/pgdocs/postgres/indexes-types.html
# constraints http://www.postgresql.org/docs/8.1/static/ddl-constraints.html#DDL-CONSTRAINTS-FK


=item create_table

Creates the table code

=cut

# http://www.postgresql.org/docs/8.1/static/ddl.html#DDL-BASICS
sub create_table {
    my $self = shift;
    my ( $table, $details ) = @_;
    my $tablecode = 'CREATE TABLE ' . $self->qid($table) . " (\n";
    my $column_count = 0;
    foreach my $column ( @{ $details->{columns} } ) {
        $tablecode .= ",\n" if $column_count > 0;
        $tablecode .= "\t" . $self->create_column($column);
        $column_count++;
    }#foreach
    $tablecode .= ",\n\t" . $self->create_primary_key( $details->{primary_key} ) if $details->{primary_key};
    $tablecode .= "\n)";
    return $tablecode;
}#sub


=item drop_index

Creates the drop index code

=cut

sub drop_index {
    my $self = shift;
    my ( $table, $index ) = @_;
    my $indexcode = q~CREATE OR REPLACE FUNCTION DropIndex(tblSchema VARCHAR, tblName VARCHAR, ndxName VARCHAR) RETURNS void AS $$
DECLARE
    exec_string TEXT;
BEGIN
    exec_string := 'ALTER TABLE ';
    IF tblSchema != NULL THEN
        exec_string := exec_string || quote_ident(tblSchema) || '.';
    END IF;
    exec_string := exec_string || quote_ident(tblName)
        || ' DROP INDEX '
        || quote_ident(ndxName);
    EXECUTE exec_string;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
$$ LANGUAGE plpgsql;
~ .
'SELECT DropIndex(NULL, ' . $self->{dbh}->quote($table) . ', ' . $self->{dbh}->quote( $index->{name} ) .' );';
    return $indexcode;
}#sub


=item drop_constraint_foreign

Creates the drop foreign constraint code

=cut

sub drop_constraint_foreign {
    my $self = shift;
    my ( $table, $constraint ) = @_;
    my $constraintcode = q~CREATE OR REPLACE FUNCTION DropConstraint(tblSchema VARCHAR, tblName VARCHAR, cstName VARCHAR) RETURNS void AS $$
DECLARE
    exec_string TEXT;
BEGIN
    exec_string := 'ALTER TABLE ';
    IF tblSchema != NULL THEN
        exec_string := exec_string || quote_ident(tblSchema) || '.';
    END IF;
    exec_string := exec_string || quote_ident(tblName)
        || ' DROP CONSTRAINT '
        || quote_ident(cstName);
    EXECUTE exec_string;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
$$ LANGUAGE plpgsql;
~ .
'SELECT DropConstraint(NULL, ' . $self->{dbh}->quote($table) . ', ' . $self->{dbh}->quote( $constraint->{name} ) .' );';
#'ALTER TABLE ' . $self->qid($table);
#    $constraintcode .= ' DROP CONSTRAINT IF EXISTS ' . $self->qid( $constraint->{name} );
    return $constraintcode;
}#sub
#select t.constraint_name, t.table_name, t.constraint_type,
#    c.table_name, c.column_name
#from information_schema.table_constraints t,
#    information_schema.constraint_column_usage c
#where t.constraint_name = c.constraint_name
#    and t.constraint_type = 'FOREIGN KEY'
#    and c.table_name = 'mytable';

=head TODO

    Move functions so that they are only declared once
    Possibly swap functions for ones that don't use EXCEPTION

=cut

1;
