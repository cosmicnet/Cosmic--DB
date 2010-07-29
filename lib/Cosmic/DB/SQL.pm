package Cosmic::DB::SQL;
use strict;
use warnings;

=pod

Master Cosmic::DB::SQL object class, used to retain info and spawn new Cosmic::DB::SQL::Generic derived objects.

=cut

sub new {
    my $class = shift;
    my ( $dbh ) = @_;
    my $self = bless { dbh => $dbh }, $class;
    return $self;
}#sub

=item

Factory for Cosmic::DB::SQL::Generic derived objects.

=cut

sub sql {
    my $self = shift;
    if ( $self->{dbh}->{Driver}->{Name} eq 'mysql' ||  $self->{dbh}->{Driver}->{Name} eq 'mysqlPP' ) {
        require Cosmic::DB::SQL::MySQL;
        return new Cosmic::DB::SQL::MySQL( $self->{dbh} );
    }#if
    else {
        croak( "DB $self->{dbh}->{Driver}->{Name} not supported" );
    }#else
}#sql


1;
