package Cosmic::DB::Schema::MySQL;
use base 'Cosmic::DB::Schema::Generic';

use strict;
use warnings;

=pod

=head Generate MySQL DDL code


=head Methods

=cut

# TODO use DBI quotes

=item load types

Adds MySQL types map to the object

=cut

# Mappings for DB datatypes
# http://dev.mysql.com/doc/refman/5.5/en/data-type-overview.html
sub load_types {
    my $self = shift;
    $self->{data_types} = {

    # Numbers

    # range -2147483648 to 2147483647
    int      => 'INT',
    # range -32768 to 32767
    smallint => 'SMALLINT',
    # range -9223372036854775808 to 9223372036854775807
    bigint   => 'BIGINT',
    # range -3.402823466E+38 to -1.175494351E-38, 0, and 1.175494351E-38 to 3.402823466E+38
    real     => 'FLOAT',
    # range -1.7976931348623157E+308 to -2.2250738585072014E-308, 0, and 2.2250738585072014E-308 to 1.7976931348623157E+308
    double   => 'DOUBLE',

    # tinyint -128 to 128
    # mediumint -8388608 to 8388607

    # Dates

    # range '1000-01-01' to '9999-12-31'
    date      => 'DATE',

    # range '-838:59:59' to '838:59:59'
    time      => 'TIME',

    # range '1000-01-01 00:00:00' to '9999-12-31 23:59:59'
    # rationale timestamp only had range '1970-01-01 00:00:01' UTC to '2038-01-19 03:14:07'
    # format YYYY-MM-DD HH:MM:SS or YY-MM-DD HH:MM:SS
    timestamp => 'DATETIME',

    ## Characters
    #
    ## range 1 through 255
    ## precision 0 to 255
    ## default 1
    #char    => 'CHAR',
    ## range 1 through 65,535
    ## precision 0 to 65,535
    #varchar => 'VARCHAR',
    ## range 65,535 (2E16 – 1)
    ## precision none
    #text    => 'TEXT',

    # Unicode Characters

    # range 1 through 255
    # precision 0 to 255
    # default 1
    char    => 'NATIONAL CHAR',
    # range 1 through 21,844
    # precision 0 through 21,844
    varchar => 'NATIONAL VARCHAR',
    # range 4,294,967,295 or 4GB (232 – 1)
    # precision none
    text    => 'LONGTEXT',

    # Special

    # serials
    # range 1 to 4294967295
    serial    => 'INT NOT NULL AUTO_INCREMENT UNIQUE',
    # range 1 to 18446744073709551615
    bigserial => 'SERIAL',
    };
}#sub

# indexes http://dev.mysql.com/doc/refman/5.1/en/create-index.html
# constraints http://dev.mysql.com/doc/refman/5.1/en/innodb-foreign-key-constraints.html


=item create_table

Creates the table code

=cut

# http://dev.mysql.com/doc/refman/5.1/en/create-table.html
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
    $tablecode .= "\n) ENGINE = InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci";
    return $tablecode;
}#sub


=item drop_index

Creates the drop index code

=cut

sub drop_index {
    my $self = shift;
    my ( $table, $index ) = @_;
#    my $indexcode = q~DELIMITER $$
#DROP PROCEDURE IF EXISTS `util`.`DropIndex` $$
#CREATE PROCEDURE `util`.`DropIndex` (tblSchema VARCHAR(64), tblName VARCHAR(64), ndxName VARCHAR(64))
#BEGIN
#    DECLARE IndexColumnCount INT;
#    DECLARE SQLStatement VARCHAR(256);
#
#    SELECT COUNT(1) INTO IndexColumnCount
#    FROM information_schema.statistics
#    WHERE table_schema = tblSchema
#    AND table_name = tblName
#    AND index_name = ndxName;
#
#    IF IndexColumnCount > 0 THEN
#        SET SQLStatement = CONCAT('ALTER TABLE `',tblSchema,'`.`',tblName,'` DROP INDEX `',ndxName,'`');
#        SET @SQLStmt = SQLStatement;
#        PREPARE s FROM @SQLStmt;
#        EXECUTE s;
#        DEALLOCATE PREPARE s;
#    END IF;
#END $$
#DELIMITER ;
#CALL DropIndex()~;
    my $indexcode = 'ALTER IGNORE TABLE ' . $self->qid($table) .
    ' DROP INDEX ' . $self->qid( $index->{name} );
    return $indexcode;
}#sub


=item drop_constraint_foreign

Creates the drop foreign constraint code

=cut

sub drop_constraint_foreign {
    my $self = shift;
    my ( $table, $constraint ) = @_;
#    my $constraintcode = q~DELIMITER $$
#DROP PROCEDURE IF EXISTS `util`.`DropFK`$$
#CREATE PROCEDURE `DropFK`()
#BEGIN
#IF EXISTS (SELECT NULL FROM information_schema.TABLE_CONSTRAINTS
#WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = ~ . $self->{dbh}->quote( $constraint->{name} ) .
#q~) THEN
#	ALTER TABLE ~ . $self->qid($table) . q~ DROP FOREIGN KEY ~ . $self->qid( $constraint->{name} ) . q~;
#END IF;
#END$$
#
#DELIMITER ;
#CALL DropFK()~;
    my $constraintcode = 'ALTER IGNORE TABLE ' . $self->qid($table) .
    ' DROP FOREIGN KEY ' . $self->qid( $constraint->{name} );
    return $constraintcode;
}#sub


1;
