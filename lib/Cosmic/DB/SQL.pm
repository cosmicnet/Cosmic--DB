package Cosmic::DB::SQL;
use strict;
use warnings;
use Carp;

=pod

Master Cosmic::DB::SQL object class, used to retain info and spawn new Cosmic::DB::SQL::Generic derived objects.

=cut

sub new {
    my $class = shift;
    my ( $dbh ) = @_;
    croak( 'No database handle passed' ) unless ref( $dbh ) eq 'DBI::db';
    my $self = bless { dbh => $dbh }, $class;
    return $self;
}#sub

=item

Factory for Cosmic::DB::SQL::Generic derived objects.

=cut

sub sql {
    my $self = shift;
    my $SQL;
    if ( $self->{dbh}->{Driver}->{Name} eq 'mysql' ||  $self->{dbh}->{Driver}->{Name} eq 'mysqlPP' ) {
        require Cosmic::DB::SQL::MySQL;
        return Cosmic::DB::SQL::MySQL->new( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'Pg' ) {
        require Cosmic::DB::SQL::Postgres;
        return new Cosmic::DB::SQL::Postgres( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'Oracle' ) {
        require Cosmic::DB::SQL::Oracle;
        return new Cosmic::DB::SQL::Oracle( $self->{dbh} );
    }#if
    if ( $self->{dbh}->{Driver}->{Name} eq 'ODBC' ) {
        # TODO extra ODBC check for SQL Server
        require Cosmic::DB::SQL::SQLServer;
        return new Cosmic::DB::SQL::SQLServer( $self->{dbh} );
    }#if

    croak( "DB $self->{dbh}->{Driver}->{Name} not supported" );
}#sql


1;
