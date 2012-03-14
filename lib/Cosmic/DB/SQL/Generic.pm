package Cosmic::DB::SQL::Generic;
use strict;
use warnings;
use Carp;
use Cosmic::DB::SQL::Placeholder;

sub new {
    my $class = shift;
    my ( $dbh ) = @_;
    croak( 'No database handle passed...' ) unless ref( $dbh ) eq 'DBI::db';
    my $self = bless { sql => '', dbh => $dbh }, $class;
    return $self;
}

=item select

Usage: $obj->select( COLUMNS )
COLUMNS may be an array

=cut

sub select {
    my $self = shift;
    croak( 'Missing column(s) from select' ) unless @_ >= 1;
    $self->{sql} .= 'SELECT ' . join(',', map { $self->_quote_column($_) } @_) . ' ';
    return $self;
}#sub

sub from {
    my $self = shift;
    croak( 'Missing table(s) from from' ) unless @_ >= 1;
    $self->{sql} .= 'FROM ' . join(',', map { $self->_quote_table($_) } @_) . ' ';
    return $self;
}#sub

sub where {
    my $self = shift;
    croak( 'Missing conditional from where' ) unless @_ >= 3;
    $self->{sql} .= 'WHERE ';
    $self->conditional( @_ );
    return $self;
}#sub

sub and {
    my $self = shift;
    croak( 'Missing conditional from and' ) unless @_ >= 3;
    $self->{sql} .= 'AND ';
    $self->conditional( @_ );
    return $self;
}#sub

sub conditional {
    my $self = shift;
    croak( 'Missing conditional from where' ) unless @_ >= 3;
    my ( $left, $comparison, $right ) = @_;
    $right = $self->_quote_value($right) unless $right eq '?';
    $self->{sql} .= $self->_quote_column($left) . $comparison . $right;
}#sub

sub insert {
    my $self = shift;
    my ( $table, $columns, $values ) = @_;
    croak( 'Missing table from insert' ) unless defined $table;
    croak( 'Missing columns from insert' ) unless ref $columns eq 'ARRAY';
    croak( 'Missing values from insert' ) unless $values;
    # Populate list of placeholders
    if ( $values eq '?' ) {
        #$values = [ map { Cosmic::DB::SQL::Placeholder->new } @$columns ];
        $values = [ map { \'?' } @$columns ];
    }#if
    #else {
    #    # Check values for placeholders
    #    foreach ( @values ) {
    #        if ( ref $_ eq 'SCALAR' && $$_ eq '?' ) {
    #            $_ = Cosmic::DB::SQL::Placeholder->new;
    #        }
    #    }
    #}
    $self->{sql} .= 'INSERT INTO ' . $self->_quote_table($table) . ' (' . join(',', map { $self->_quote_column($_) } @$columns) . ') ';
    if ( ref $values eq 'ARRAY' ) {
        $self->{sql} .= 'VALUES (' . join(',', map { $self->_quote_value($_) } @$values) . ') ';
    }
    else {
        $self->{sql} .= $values;
    }
    return $self;
}#sub

sub delete {
    my $self = shift;
    $self->{sql} .= 'DELETE ';
    return $self;
}#sub

sub update {
    my $self = shift;
    croak( 'Missing table from insert' ) unless defined $_[0];
    $self->{sql} .= 'UPDATE ' . $self->_quote_table($_[0]) . ' ';
    return $self;
}#sub

sub set {
    my $self = shift;
    $self->{sql} .= 'SET ';
    croak( 'Arguments must be even' ) if @_ % 2;
    while ( @_ ) {
        $self->assignment( shift, shift );
        $self->{sql} .= ', 'if @_;
    }#while
    return $self;
}#sub

sub assignment {
    my $self = shift;
    croak( 'Missing arguement from assignment' ) unless @_ >= 2;
    my ( $left, $right ) = @_;
    $right = $self->_quote_value($right) unless $right eq '?';
    $self->{sql} .= $self->_quote_column($left) . '=' . $self->_quote_value($right);
}#sub

sub _quote_value {
    my $self = shift;
    if ( ref $_[0] ) {
        if ( ref $_[0] eq 'Cosmic::DB::SQL::Placeholder' ) {
            return '?';
        }
        else {
            return ${$_[0]};
        }
    }#if
    else {
        return $self->{dbh}->quote($_[0]);
    }#else
}#sub

sub _quote_column {
    my $self = shift;
    if ( $_[0] eq '*' ) {
        return $_[0];
    }#if
    else {
        return $self->{dbh}->quote_identifier(undef, undef, $_[0]);
    }#else
}#sub

sub _quote_table {
    my $self = shift;
    if ( ref $_[0] eq 'ARRAY' ) {
        return $self->{dbh}->quote_identifier(undef, $_[0]->[0], $_[0]->[1]);
    }#if
    elsif ( $_[0] =~ /^(.*)?\.(.*)?$/ ) {
        return $self->{dbh}->quote_identifier(undef, $1, $2);
    }#elsif
    else {
        return $self->{dbh}->quote_identifier($_[0]);
    }#else
}#sub

sub sql {
    my $self = shift;
    return $self->{sql};
}#sub

1;
