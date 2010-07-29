package Cosmic::DB::Schema::SQLServer;
use base 'Cosmic::DB::Schema::Generic';

use strict;
use warnings;

=pod

=head Generate MS SQL Server DDL code


=head Functions

=cut


# Mappings for DB datatypes
# http://msdn.microsoft.com/en-us/library/ms187752.aspx
sub load_types {
    my $self = shift;
    $self->{data_types} = {

    # Numbers

    # range -2^31 (-2,147,483,648) to 2^31-1 (2,147,483,647)
    # precision none
    int     => 'INT',
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
    double => 'FLOAT(53)',

    # smallint -32768 to 32767
    # bigint -9223372036854775808 to 9223372036854775807

    # Date

    # range 0001-01-01 through 9999-12-31
    date      => 'DATE',

    # range 00:00:00.0000000 through 23:59:59.9999999
    time      => 'TIME',

    # range 0001-01-01 through 9999-12-31
    # format iso 2004-05-23T14:25:10
    timestamp => 'DATETIME2',

    ## Characters
    #
    ## range 1 through 8,000
    ## precision 1 through 8,000
    #char    => 'char',
    ## range 1 through 8,000
    ## precision 1 through 8,000
    #varchar => 'varchar',
    ## range 2^31-1 (2,147,483,647)
    ## precision none
    #text    => 'text',

    # Unicode Characters

    # range 1 through 4,000
    # precision 1 through 4,000
    char    => 'NCHAR',
    # range 1 through 4,000
    # precision 1 through 4,000
    varchar => 'NVARCHAR',
    # range 2^30 - 1 (1,073,741,823)
    # precision none
    text    => 'NTEXT',

    # Special

    # serials
    # range 1 to 2147483647
    serial    => 'INT IDENTITY(1,1) UNIQUE',
    # range 1 to 9223372036854775807
    bigserial => 'BIGINT IDENTITY(1,1) UNIQUE',
    };
}#sub

# indexes http://msdn.microsoft.com/en-us/library/ms188783.aspx
# constraints http://msdn.microsoft.com/en-us/library/ms177463.aspx


=item create_table

Creates the table code

=cut

# http://msdn.microsoft.com/en-us/library/aa258255%28SQL.80%29.aspx
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


=item drop_table

Creates the drop table code

=cut

sub drop_table {
    my $self = shift;
    my ( $table, $details ) = @_;
    my $tablecode = q~IF EXISTS
    (SELECT 1 FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'~ . $table . q~') AND type = (N'U'))
    DROP TABLE ~ . $self->qid($table);
    return $tablecode;
}#sub


=item drop_index

Creates the drop index code

=cut

sub drop_index {
    my $self = shift;
    my ( $table, $index ) = @_;
    my $indexcode = q~IF EXISTS (SELECT name FROM sysindexes WHERE name = ~ . $self->{dbh}->quote( $index->{name} ) . q~)
    DROP INDEX ~ . $self->qid($table) . '.' . $self->qid( $index->{name} );
    return $indexcode;
}#sub


=item drop_constraint_foreign

Creates the drop foreign constraint code

=cut

sub drop_constraint_foreign {
    my $self = shift;
    my ( $table, $constraint ) = @_;
    my $constraintcode = q~IF EXISTS
    (SELECT 1 FROM sys.foreign_keys WHERE OBJECT_ID = OBJECT_ID(N'dbo.~ . $constraint->{name} .
    q~') AND parent_object_id = OBJECT_ID(N'dbo.~ . $table . q~'))
    ALTER TABLE dbo.~ . $self->qid($table) . q~
    DROP CONSTRAINT ~ . $self->qid( $constraint->{name} );
    return $constraintcode;
}#sub


1;
