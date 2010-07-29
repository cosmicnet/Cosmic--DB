package Cosmic::DB::Schema;
use strict;
use warnings;
use Carp;

=pod

=head1 Schema

Methods for defining, loading and creating DB schemas

=head1 Methodology

1) Create tables with primary keys
2) Create indexes
3) Create foreign key constraints

 my $schema = {
    table => {
        columns => [
            {
                name    => 'COLUMN',
                type    => 'ALLOWED TYPE',
                unique  => 0|1,
                null    => 0|1,
                size    => [0-9]*,
                default => '',
            }
        ],
        primary_key => [
            'COLUMN',
        ],
        indexes => [
            {
                name    => 'INDEX NAME',
                unique  => 0|1,
                columns => [
                    'COLUMN',
                ],
            },
        ],
        constraints => {
            foreign => [
                {
                    name    => 'CONSTRAINT NAME',
                    columns => [
                        'COLUMN',
                    ],
                    references => {
                        table => 'TABLE',
                        columns => [
                            'COLUMN',
                        ],
                    },
                    cascade => 0|1,
                },
            ],
        },
    },
};

=head1 Allowed types

=head2 Numeric

All numbers are signed (apart from some serials). Numbers are of fixed size,
i.e int(10) is invalid.

=item int

Safe range -2147483648 to 2147483647

=item smallint

Safe range -32768 to 32767

=item bigint

Safe range -9223372036854775808 to 9223372036854775807

=item real

Safe range - 3.40E + 38 to -1.18E - 38, 0 and 1.18E - 38 to 3.40E + 38

=item double

Safe range - 1.79E+308 to -2.23E-308, 0 and 2.23E-308 to 1.79E+308

=head2 Dates and times

Always store dates in the database as GMT (UTC), you shouldn't be storing
timezones in the DB (and we don't plan to support it).
Date implementations vary a lot, you might be better off just using integers,
such as 20100101 for 1st of January 2010.

=item date

Safe range '1000-01-01' to '9999-12-31'

=item time

Safe range 00:00:00 to 23:59:59

=item timezone

Safe range '1000-01-01 00:00:00' to '9999-12-31 23:59:59'
Format YYYY-MM-DD HH:MM:SS

=head2 Strings

By default all strings are created unicode compatible. You should be planning
for wide characters in the first place, it'll save you much pain later.
It is possible to use the standard ASCII string types by TODO

=item char

Safe range 1 to 255
Default 1

=item varchar

Safe range 1 to 2000

=item text

Safe storage up to 2GB

=head2 Special

=item serial

Safe range 1 to 2147483647 (int based)

Beware oracle warning below

=item bigserial

Safe range 1 to 9223372036854775807 (bigint based)

=head1 FAQ

=item Why no ON UPDATE CASCADE?

Oracle doesn't support it, and for good reason.
http://asktom.oracle.com/pls/asktom/f?p=100:11:0::::P11_QUESTION_ID:5773459616034

=head1 Known issues

=item MySQL floats

MySQL uses doubles for internal calculations, so floats may not calculate the
same as the other dbs

=item Oracle unicode

SELECT translated_description FROM product_descriptions
   WHERE translated_name = N'LCD Monitor 11/PM';

=item Oracle auto increment

Much more complicated. We automatically create a sequence and trigger

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

=item Postgres index names must be unique across tables

It appears so. Should we automatically append table name to postgres indexes???

=item Oracle dates and times

Oracle date fields are different, they include a time and must be formatted.
The helper method TODO is provided to eleviate this problem. Oracle also has no
native time, we use a timestamp field with date 1000-01-01 to simulate.

=item SQL Server serials

To explicitly insert a serial, you must first run

    SET IDENTITY_INSERT "I<TABLE>" ON

The helper method TODO is provided to eliviate this problem.

=head1 methods

=cut

=item new

    $db_schema = new Cosmic::DB::Schema( $dbh );

=cut

sub new {
    my $class = shift;
    my ( $dbh ) = @_;
    croak( 'No database handle passed' ) unless ref( $dbh ) eq 'DBI::db';
    my $self = bless { dbh => $dbh }, $class;
    return $self;
}#sub


=item load

    $db_schema->load( $schema );

=cut

sub load {
    my $self = shift;
    $self->{schema} = $_[0];
    # TODO load from JSON, YAML, XML
    # TODO validation
    return $self;
}#sub


=item create

    my $ddl = $db_schema->create;

=cut

sub create {
    my $self = shift;
    my %options = @_;
    my $schema;
    if ( $self->{dbh}->{Driver}->{Name} eq 'mysql' ||  $self->{dbh}->{Driver}->{Name} eq 'mysqlPP' ) {
        require Cosmic::DB::Schema::MySQL;
        $schema = new Cosmic::DB::Schema::MySQL( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'Pg' ) {
        require Cosmic::DB::Schema::Postgres;
        $schema = new Cosmic::DB::Schema::Postgres( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'Oracle' ) {
        require Cosmic::DB::Schema::Oracle;
        $schema = new Cosmic::DB::Schema::Oracle( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'ODBC' ) {
        # TODO extra ODBC check for SQL Server
        require Cosmic::DB::Schema::SQLServer;
        $schema = new Cosmic::DB::Schema::SQLServer( $self->{dbh} );
    }#if
    if ( $schema ) {
        $options{schema} = $self->{schema};
        return wantarray ? ( $schema->producer( %options ) ) : $schema->producer( %options );
    }#if
    else {
        croak( "DB $self->{dbh}->{Driver}->{Name} not supported" );
    }#else
}#sub


1;
