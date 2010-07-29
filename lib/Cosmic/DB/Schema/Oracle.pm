package Cosmic::DB::Schema::Oracle;
use base 'Cosmic::DB::Schema::Generic';

use strict;
use warnings;

=pod

=head Generate Oracle DDL code


=head Functions

=cut


# Mappings for DB datatypes
#http://www.sysdba.de/oracle-dokumentation/11.1/server.111/b28286/sql_elements001.htm#SQLRF0021
sub load_types {
    my $self = shift;
    $self->{data_types} = {
    # Numbers

    # number can have range 1.0 x 1E0-130 to but not including 1.0 x 10E126
    # number precision 1 to 38
    # range -9999999999 to 9999999999
    int     => 'NUMBER(10)',
    # range -99999 to 99999
    smallint => 'NUMBER(5)',
    # range -9999999999999999999 to 9999999999999999999
    bigint   => 'NUMBER(19)',
    # range 1.0 x 10E-130 to but not including 1.0 x 10E126
    # precision 1 to 38
    # byte 4
    real   => 'BINARY_FLOAT',#'FLOAT(63)',
    # range 1.0 x 10E-130 to but not including 1.0 x 10E126
    # precision 1 to 38
    # byte 8
    double => 'BINARY_DOUBLE',#'FLOAT(126)',

    # Dates

    # range '-4712-01-01' to '9999-12-31' excluding year 0
    # notes actually stores time as well
    date      => 'DATE',

    # range '00:00:00' to '23:59:59'
    # notes actually stores date as well
    time      => 'TIMESTAMP',

    # range '-4712-01-01 00:00:00' to '9999-12-31 23:59:59'
    timestamp => 'TIMESTAMP',

    ## Characters
    #
    ## range 1 to 2000 bytes
    ## precision 1 to 2000
    ## default 1
    #char    => 'CHAR',
    ## range 1 to 4000 bytes
    ## precision 1 to 4000
    #varchar => 'VARCHAR2',
    ## range (4 gigabytes - 1) * (database block size).
    ## precision none
    #text    => 'CLOB',

    # Unicode Characters

    # range 1 to 2000 bytes
    # precision specified in characters, depends on character set
    char    => 'NCHAR',
    # range 1 to 4000 bytes
    # precision specified in characters, depends on character set
    varchar => 'NVARCHAR2',
    # range (4 gigabytes - 1) * (database block size).
    # precision none
    text    => 'NCLOB',

    # Special

    # serials
    serial    => 'NUMBER(10) UNIQUE',
    bigserial => 'NUMBER(38) UNIQUE',
    # additional code is needed:-
    #create sequence test_seq
    #start with 1
    #increment by 1
    #nomaxvalue;
    #
    #create trigger test_trigger
    #before insert on my_test
    #for each row
    #begin
    #select test_seq.nextval into :new.id from dual;
    #end;
    };
}#sub

# indexes http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/statements_5011.htm#SQLRF01209
# constraints http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/clauses002.htm#i1036780


=item create_table

Creates the table code

=cut

# http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/statements_7002.htm#i2201774
sub create_table {
    my $self = shift;
    my ( $table, $details ) = @_;
    my $tablecode = 'CREATE TABLE ' . $self->qid($table) . " (\n";
    my $column_count = 0;
    foreach my $column ( @{ $details->{columns} } ) {
        $tablecode .= ",\n" if $column_count > 0;
        $tablecode .= "\t" . $self->create_column($column);
        # Check if this is a serial and needs extra code
        if ( lc( $column->{type} ) =~ /^(?:big)?serial$/ ) {
            push( @{ $self->{ddlcode}->{extras} }, $self->create_serial_extra( $table, $column ) );
            push( @{ $self->{ddlcode}->{drop_extras} }, $self->drop_serial_extra( $table, $column ) ) if $self->{options}->{drop};
        }#if
        $column_count++;
    }#foreach
    $tablecode .= ",\n\t" . $self->create_primary_key( $details->{primary_key} ) if $details->{primary_key};
    $tablecode .= "\n)";
    return $tablecode;
}#sub


=item drop_table

Creates the drop table code

=cut

sub drop_table {
    my $self = shift;
    my ( $table, $details ) = @_;
    my $tablecode = 'DECLARE
v_count NUMBER :=0;
BEGIN
SELECT COUNT(*) INTO v_count FROM all_tables WHERE table_name=' .
$self->{dbh}->quote($table) . ' AND owner=' . $self->{dbh}->quote( $self->{dbh}->{Username} ) . ";\n" .
q~IF v_count = 1 THEN
EXECUTE IMMEDIATE 'DROP TABLE ~ . $self->qid( $self->{dbh}->{Username} ) . '.' .
$self->qid($table) . q~';
END IF;
END;~;
    return $tablecode;
}#sub


=item drop_index

Creates the drop index code

=cut

sub drop_index {
    my $self = shift;
    my ( $table, $index ) = @_;
    my $indexcode = q~BEGIN
EXECUTE IMMEDIATE ('DROP INDEX ~ . $self->qid( $index->{name} ) . q~');
EXCEPTION
WHEN OTHERS THEN
NULL;
END;~;
    return $indexcode;
}#sub


=item drop_constraint_foreign

Creates the drop foreign constraint code

=cut

sub drop_constraint_foreign {
    my $self = shift;
    my ( $table, $constraint ) = @_;
    my $constraintcode = q~BEGIN
EXECUTE IMMEDIATE ('ALTER TABLE ~ . $self->qid( $table ) .
q~ DROP CONSTRAINT ~ . $self->qid( $constraint->{name} ) . q~');
EXCEPTION
WHEN OTHERS THEN
NULL;
END;~;
    return $constraintcode;
}#sub


=item create_serial_extra

Creates the extra sequence table and trigger code

=cut

sub create_serial_extra {
    my $self = shift;
    my ( $table, $column ) = @_;
    my $sequencecode = 'CREATE SEQUENCE ' . $self->qid( "${table}_seq" );
    $sequencecode .= qq~
    START WITH 1
    INCREMENT BY 1
    NOMAXVALUE~;
    my $triggercode = 'CREATE TRIGGER ' . $self->qid( "${table}_trigger" );
    $triggercode .= "\nBEFORE INSERT ON " . $self->qid($table);
    $triggercode .= qq~
    FOR EACH ROW
    BEGIN\n~;
    $triggercode .= 'SELECT ' . $self->qid( "${table}_seq" ) . '.NEXTVAL ';
    $triggercode .= 'INTO :NEW.' . $self->qid( $column->{name} ) . " FROM DUAL;\n";
    $triggercode .= 'END;';
    return ($sequencecode, $triggercode);
}#sub


=item drop_serial_extra

Creates the drop sequence table and trigger code

=cut

sub drop_serial_extra {
    my $self = shift;
    my ( $table, $column ) = @_;
#    my $triggercode = q~DROP TRIGGER ~ . $self->qid( "${table}_trigger" );
    my $triggercode = q~BEGIN
EXECUTE IMMEDIATE ('DROP TRIGGER ~ . $self->qid( "${table}_trigger" ) . q~');
EXCEPTION
WHEN OTHERS THEN
NULL;
END;~;
#    my $sequencecode = q~DROP SEQUENCE ~ . $self->qid( "${table}_seq" );
    my $sequencecode = q~BEGIN
EXECUTE IMMEDIATE ('DROP SEQUENCE ~ . $self->qid( "${table}_seq" ) . q~');
EXCEPTION
WHEN OTHERS THEN
NULL;
END;~;
    return ($triggercode, $sequencecode);
}#sub


1;
